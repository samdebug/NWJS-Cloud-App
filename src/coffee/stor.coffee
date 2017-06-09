class ResSource
    constructor: (@rest, @process) ->
        @items = []
        @map   = {}

    update: () =>
        @rest.list().done (data) =>
            if data.status == "success"
                @_update_data data.detail
            else
                @_update_data []
        .fail (jqXHR, text_status, e) =>
            @_update_data []

    get: (id) => @map[id]
        
    _update_data: (data) =>
        if @process
            data = @process(data)
        @items = data
        @map = {}
        for o in @items
            @map[o.id] = o
        @notify_updated()

    notify_updated: () =>
        $(this).triggerHandler "updated", this

class SingleSource
    constructor: (@rest, @default) ->
        @data = @default

    update: () =>
        @rest.query().done (data) =>
            if data.status == "success"
                @data = data.detail
            else
                @data = @default
            @notify_updated()
        .fail (jqXHR, text_status, e) =>
            @data = @default
            @notify_updated()

    notify_updated: () =>
        $(this).triggerHandler "updated", this

class Chain
    constructor: (@errc) ->
        @dfd = $.Deferred()
        @chains = []
        @total = 0

    chain: (arg) =>
        if arg instanceof Chain
            queue = arg.chains
        else if $.isArray arg
            queue = arg
        else
            queue = [arg]
        for step in queue
            @chains.push step
            @total += 1
        return this

    _notify_progress: () =>
        $(this).triggerHandler "progress", ratio: (@total-@chains.length)/@total

    _done: (data, text_status, jqXHR) =>
        if @chains.length == 0
            $(this).triggerHandler "completed"
            temp_data.push data
            @dfd.resolve()
        else
            [@cur, @chains...] = @chains
            jqXHR = @cur()
            @_notify_progress()
            jqXHR.done(@_done).fail(@_fail)

    _fail: (jqXHR, text_status, e) =>
        reason = if jqXHR.status == 400 then JSON.parse(jqXHR.responseText) else text_status
        $(this).triggerHandler "error", error: reason, step: @cur
        if @errc
            @errc error: reason, step: @cur
            @_done()
        else
            @dfd.reject jqXHR.status, reason

    execute: () =>
        @_done()
        @promise = @dfd.promise()
        @promise

class StorageData
    constructor: (@host) ->
        @_update_queue = []
        @_deps =
           disks: ["disks", "raids", "journals"]
           raids: ["disks", "raids", "journals"]
           volumes: ["raids", "volumes", "initrs", "journals"]
           initrs: ["volumes", "initrs", "journals"]
           networks: ["networks", "gateway", "journals"]
           monfs: ["monfs", "volumes", "journals"]
           filesystem: ["filesystem", "volumes", "journals"]
           all: ["dsus", "disks", "raids", "volumes", "initrs", "networks", "journals", "gateway", "filesystem", "systeminfo"]


        @disks = new ResSource(new DiskRest(@host))
        @raids = new ResSource(new RaidRest(@host))
        @volumes = new ResSource(new VolumeRest(@host))
        @initrs = new ResSource(new InitiatorRest(@host))
        @networks = new ResSource(new NetworkRest(@host))
        @journals = new ResSource(new JournalRest(@host))
        @dsus = new ResSource(new DSURest(@host))
        
        @gateway = new SingleSource(new GatewayRest(@host), ipaddr: "")
        @monfs = new SingleSource(new MonFSRest(@host), {})
        @filesystem = new SingleSource(new FileSystemRest(@host), {})
        @systeminfo = new SingleSource(new SystemInfoRest(@host), version: "UNKOWN")

        
        @stats = items: []
        @socket_statist = io.connect "#{@host}/statistics", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_statist.on "statistics", (data) =>               #get read_mb and write_mb
            if @stats.items.length > 120
                @stats.items.shift()
            @stats.items.push(data)
            $(@stats).triggerHandler "updated", @stats

        @socket_event = io.connect "#{@host}/event", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_event.on "event", @feed_event
        @socket_event.on "disconnect", @disconnect_listener
        @_update_loop()

    raid_disks: (raid) =>
        disks = (d for d in @disks.items when d.raid == raid.name)
        disks.sort (o1,o2) -> o1.slot - o2.slot
        return disks

    volume_initrs: (volume) =>
        (initr for initr in @initrs.items when volume.name in (v for v in initr.volumes))

    initr_volumes: (initr) =>
        (v for v in @volumes.items when v.name in initr.volumes)

    spare_volumes: () =>
        used = []
        for initr in @initrs.items
            used = used.concat(initr.volumes)
        volume for volume in @volumes.items when volume.name not in used

    feed_event: (e) =>
        console.log e
        switch e.event
            when "disk.ioerror", "disk.formated", "disk.plugged", "disk.unplugged"
                @_update_queue.push @disks
                @_update_queue.push @journals
            when "disk.role_changed"
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.normal", "raid.degraded", "raid.failed"
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.rebuild"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid
            when "raid.rebuild_done"
                raid = @raids.get e.raid
                if raid != undefined
                    raid.rebuilding = e.rebuilding
                    raid.health = e.health
                    raid.rebuild_progress = e.rebuild_progress
                    $(this).triggerHandler "raid", raid
                    @_update_queue.push @disks
            when "raid.created", "raid.removed"           
                @_update_queue.push @disks
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "raid.rqr"
                raid = @raids.get e.raid
                raid.rqr_count = e.rqr_count
                $(this).triggerHandler "raid", raid
            when "volume.failed", "volume.normal"
                volume = @volumes.get e.uuid
                if volume != undefined
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
                    @_update_queue.push @volumes
                    @_update_queue.push @journals
            when "volume.created"         
                @_update_queue.push @volumes
                @_update_queue.push @raids
                @_update_queue.push @journals
                volume = event : e.event
                $(this).triggerHandler "volume", volume
                #volume = sync:e.sync, sync_progress: e.sync_progress, id: e.uuid
                #$(this).triggerHandler "volume", volume
            when "volume.removed"
                @_update_queue.push @volumes
                @_update_queue.push @raids
                @_update_queue.push @journals
            when "volume.sync"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
            when "volume.syncing"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume                
            when "volume.sync_done"
                volume = @volumes.get e.lun
                if volume != undefined
                    volume.sync_progress = e.sync_progress
                    volume.syncing = e.syncing
                    volume.event = e.event
                    $(this).triggerHandler "volume", volume
            when "initiator.created", "initiator.removed"
                @_update_queue.push @initrs
                @_update_queue.push @journals
            when "initiator.session_change"
                initr = @initrs.get e.initiator
                initr.active_session = e.session
                $(this).triggerHandler "initr", initr
            when "vi.mapped", "vi.unmapped"
                @_update_queue.push @initrs
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "monfs.created", "monfs.removed"
                @_update_queue.push @monfs
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "fs.created", "fs.removed"
                @_update_queue.push @filesystem
                @_update_queue.push @volumes
                @_update_queue.push @journals
            when "notification"
                $(this).triggerHandler "notification", e
            when "user.login"
                $(this).triggerHandler "user_login", e.login_id
            
    update: (res, errc) =>
        chain = new Chain errc
        chain.chain(($.map @_deps[res], (name) => (=> this[name].update())))
        chain

    _update_loop: =>
        @_looper_id = setInterval((=>
            @_update_queue = unique @_update_queue
            @_update_queue[0].update?() if @_update_queue[0]?
            @_update_queue = @_update_queue[1...]
            return
            ), 1000)

    close_socket: =>
        @socket_event.disconnect()
        @socket_statist.disconnect()
        clearInterval @_looper_id if @_looper_id?
        return

    disconnect_listener: =>
        $(this).triggerHandler "disconnect", @host

class CentralStorageData
    constructor: (@host) ->
        @_update_queue = []
        @_deps =
           centers: ["centers","journals"]
           clouds: ["clouds","journals"]
           machinedetails:['machinedetails',"journals"]
           warnings: ["warnings","journals"]
           emails: ["emails","journals"]
           colonys: ["colonys","journals"]
           stores: ["stores","journals"]
           disks: ["disks", "raids","journals"]
           raids: ["disks", "raids","journals"]
           volumes: ["raids", "volumes", "initrs","journals"]
           initrs: ["volumes", "initrs","journals"]
           networks: ["networks", "gateway","journals"]
           monfs: ["monfs", "volumes","journals"]
           filesystem: ["filesystem", "volumes","journals"]
           #all: ["centers", "networks", "journals", "gateway", "filesystem", "systeminfo"]
           all: ["centers","clouds","stores","warnings","emails","machinedetails","journals","colonys"]

        @centers = new ResSource(new CenterRest(@host))
        @clouds = new ResSource(new CloudRest(@host))
        @stores = new ResSource(new StoreRest(@host))
        @journals = new ResSource(new JournalRest(@host))
        @warnings = new ResSource(new WarningRest(@host))
        @emails = new ResSource(new EmailRest(@host))
        @machinedetails = new ResSource(new MachineDetailRest(@host))
        @colonys = new ResSource(new ColonyRest(@host))
        
        @stats = items: []
        @raids = items: []
        
        ###port1 = @host.split(':')[0] + ':5000'
        @socket_statist = io.connect "#{port1}/statistics", {
            "reconnect": false,
            "force new connection": true
        }
        
        @socket_statist.on "statistics", (data) =>
            console.log data
            if @stats.items.length > 120
                @stats.items.shift()
            try
                datas = @_data(data)
                @stats.items.push(datas)
                $(@stats).triggerHandler "updated", @stats
            catch e
                return###
                
        port2 = @host.split(':')[0] + ':8012'
        @socket_event = io.connect "#{port2}/event", {
            "reconnect": false,
            "force new connection": true
        }
        @socket_event.on "event", @feed_event
        @socket_event.on "disconnect", @disconnect_listener

        @_update_loop()
        @read_total = 0
        @write_total = 0
        
        try
            port1 = @host.split(':')[0] + ':5000';
            @ws = new WebSocket('ws://' + port1 + '/ws/info');
            @ws.onmessage = @_data;
            @ws.onclose = @disConnect;
        catch e
            return
            
        #console.log(@socket_event);
        #console.log(@ws);
        
    disConnect:() =>
        setTimeout((=>
            @ws_connect();
        ), 5000)
        
    ws_connect:() =>
        try
            port1 = @host.split(':')[0] + ':5000';
            @ws = new WebSocket('ws://' + port1 + '/ws/info');
            @ws.onmessage = @_data;
            @ws.onclose = @disConnect;
        catch e
            return
        
    _data: (data) =>
        datas = JSON.parse(data.data)
        #console.log(datas);
        socket_data = {}
        volume_overview = []
        try
            #服务器
            for i in ['server_cpu','server_mem','server_cache','server_receive',\
                      'server_sent', "server_system","server_cap","temp","server_net_write", \
                      "server_net_read", "server_vol_write","server_vol_read","exports", \
                      "server_docker","server_tmp","server_var","server_system_cap","server_weed_cpu", \
                      "server_weed_mem","server_total_read","server_total_write"]
                      
                socket_data[i] = 0
            #存储
            for i in ['store_cpu','store_mem','store_cache',"store_net_write", "store_net_read", "store_vol_write", \
                      "store_vol_read","break_number", "raid_number", "volume_number", "disk_number", \
                      "store_system","store_cap","storages","store_cap_total",'store_cap_remain',\
                      'store_var','store_weed_cpu','store_weed_mem']
                      
                socket_data[i] = 0
                
            if datas.exports.length
                for i in datas.exports
                    socket_data['server_cpu'] = socket_data['server_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['server_mem'] = socket_data['server_mem'] + i.info[i.info.length - 1].mem
                    socket_data['server_net_write'] = socket_data['server_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['server_net_read'] = socket_data['server_net_read'] + i.info[i.info.length - 1].read_mb
                    
                    for j in i.info[i.info.length - 1].df
                        socket_data['server_' + j.name] = socket_data['server_' + j.name] + j.used_per
               
                socket_data['server_cpu'] = parseInt((socket_data['server_cpu']/datas.exports.length) + (Math.random())*2)
                socket_data['server_mem'] = parseInt((socket_data['server_mem']/datas.exports.length) + (Math.random())*2)
                socket_data['server_system'] = parseInt(socket_data['server_system']/datas.exports.length)
                socket_data['server_docker'] = parseInt(socket_data['server_docker']/datas.exports.length)
                socket_data['server_tmp'] = parseInt(socket_data['server_tmp']/datas.exports.length)
                socket_data['server_var'] = parseInt(socket_data['server_var']/datas.exports.length)
                socket_data['server_system_cap'] = parseInt(socket_data['server_system_cap']/datas.exports.length)
                socket_data['server_weed_cpu'] = parseInt(socket_data['server_weed_cpu']/datas.exports.length)
                socket_data['server_weed_mem'] = parseInt(socket_data['server_weed_mem']/datas.exports.length)
                socket_data['server_total_read'] = @read_total
                socket_data['server_total_write'] = @write_total
                socket_data["exports"] = datas.exports
                @read_total = @read_total + socket_data['server_net_read']
                @write_total = @write_total + socket_data['server_net_write']
                
            if datas.storages.length
                for i in datas.storages
                    socket_data['store_cpu'] = socket_data['store_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['store_mem'] = socket_data['store_mem'] + i.info[i.info.length - 1].mem
                    socket_data['temp'] = socket_data['temp'] + i.info[i.info.length - 1].temp
                    socket_data['store_net_write'] = socket_data['store_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['store_net_read'] = socket_data['store_net_read'] + i.info[i.info.length - 1].read_mb
                    socket_data['store_vol_write'] = socket_data['store_vol_write'] + i.info[i.info.length - 1].write_vol
                    socket_data['store_vol_read'] = socket_data['store_vol_read'] + i.info[i.info.length - 1].read_vol
                    if i.info[i.info.length - 1].cache_total isnt 0
                        socket_data['store_cache'] = socket_data['store_cache'] + i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total

                    for h in i.info[i.info.length - 1].df
                        socket_data['store_' + h.name] = socket_data['store_' + h.name] + h.used_per
                        
                    for h in i.info[i.info.length - 1].fs
                        volume_overview.push({"name":h.name,"ip":i.ip,"used":h.used_per,"avail":h.available,"total":h.total})
                        
                if volume_overview.length
                    for k in volume_overview
                        socket_data['store_cap'] = parseInt(socket_data['store_cap'] + k.used)
                        socket_data['store_cap_total'] = parseInt(socket_data['store_cap_total'] + k.total)
                        socket_data['store_cap_remain'] = parseInt(socket_data['store_cap_remain'] + k.avail)
                    
                    socket_data['store_cap'] = socket_data['store_cap']/volume_overview.length
                    #socket_data['store_cap_total'] = socket_data['store_cap_total']/volume_overview.length
                    #socket_data['store_cap_remain'] = socket_data['store_cap_remain']/volume_overview.length
                
                socket_data['store_cpu'] = parseInt((socket_data['store_cpu']/datas.storages.length) + (Math.random())*2)
                socket_data['store_mem'] = parseInt((socket_data['store_mem']/datas.storages.length) + (Math.random())*2)
                socket_data['store_cache'] = parseInt(socket_data['store_cache']/datas.storages.length)
                socket_data['store_var'] = parseInt(socket_data['store_var']/datas.storages.length)
                socket_data['store_weed_mem'] = parseInt(socket_data['store_weed_mem']/datas.storages.length)
                socket_data['store_weed_cpu'] = parseInt(socket_data['store_weed_cpu']/datas.storages.length)
                socket_data['store_system'] = parseInt(socket_data['store_system']/datas.storages.length)
                socket_data['temp'] = parseInt((socket_data['temp']/datas.storages.length) + (Math.random())*5)
                socket_data['storages'] = datas.storages
                socket_data['volume_overview'] = volume_overview
        catch e
            console.log e
        #console.log(socket_data);
        if @stats.items.length > 30
            @stats.items.shift()
        
        try
            @stats.items.push(socket_data)
            $(@stats).triggerHandler "updated", @stats
        catch e
            return
        
    ###_data: (data) =>
        try
            socket_data = {}
            for i in ['server_cpu','server_mem','server_cache','store_cpu', \
                      'store_mem','store_cache','server_receive','server_sent', \
                      "store_net_write", "store_net_read", "store_vol_write", \
                      "store_vol_read","break_number", "raid_number", "volume_number", "disk_number", \
                      "store_system","store_cap","server_system","server_cap","temp","server_net_write", \
                      "server_net_read", "server_vol_write","server_vol_read","storages","exports","store_cap_total",'store_cap_remain', \
                      "server_docker","server_tmp","server_var","server_system_cap","server_weed_cpu","server_weed_mem",\
                      "server_total_read","server_total_write"]
                      
                socket_data[i] = 0

            if data.exports.length
                for i in data.exports
                    socket_data['server_cpu'] = socket_data['server_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['server_mem'] = socket_data['server_mem'] + i.info[i.info.length - 1].mem
                    socket_data['server_net_write'] = socket_data['server_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['server_net_read'] = socket_data['server_net_read'] + i.info[i.info.length - 1].read_mb
                    socket_data['server_system'] = socket_data['server_system'] + i.info[i.info.length - 1].df[0].used_per
                    
                socket_data['server_cpu'] = (socket_data['server_cpu']/data.exports.length) + (Math.random())*2
                socket_data['server_mem'] = (socket_data['server_mem']/data.exports.length) + (Math.random())*2
                socket_data['server_vol_write'] = 0
                socket_data['server_vol_read'] = 0
                socket_data['server_cache'] = 0
                socket_data['server_cap'] = 0
                socket_data["exports"] = data.exports
                
            if data.storages.length
                for i in data.storages
                    socket_data['store_cpu'] = socket_data['store_cpu'] + i.info[i.info.length - 1].cpu
                    socket_data['store_mem'] = socket_data['store_mem'] + i.info[i.info.length - 1].mem
                    socket_data['temp'] = socket_data['temp'] + i.info[i.info.length - 1].temp
                    socket_data['store_net_write'] = socket_data['store_net_write'] + i.info[i.info.length - 1].write_mb
                    socket_data['store_net_read'] = socket_data['store_net_read'] + i.info[i.info.length - 1].read_mb
                    socket_data['store_vol_write'] = socket_data['store_vol_write'] + i.info[i.info.length - 1].write_vol
                    socket_data['store_vol_read'] = socket_data['store_vol_read'] + i.info[i.info.length - 1].read_vol
                    if i.info[i.info.length - 1].cache_total isnt 0
                        socket_data['store_cache'] = socket_data['store_cache'] + i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total
                    if i.info[i.info.length - 1].df.length is 2
                        socket_data['store_system'] = socket_data['store_system'] + i.info[i.info.length - 1].df[0].used_per
                        socket_data['store_cap'] = socket_data['store_cap'] + i.info[i.info.length - 1].df[1].used_per
                        socket_data['store_cap_total'] = socket_data['store_cap_total'] + i.info[i.info.length - 1].df[1].total
                        socket_data['store_cap_remain'] = socket_data['store_cap_remain'] + i.info[i.info.length - 1].df[1].available
                    else
                        socket_data['store_system'] = socket_data['store_system'] + i.info[i.info.length - 1].df[0].used_per
                socket_data['store_cpu'] = (socket_data['store_cpu']/data.storages.length) + (Math.random())*2
                socket_data['store_mem'] = (socket_data['store_mem']/data.storages.length) + (Math.random())*2
                socket_data['store_cache'] = socket_data['store_cache']/data.storages.length
                socket_data['store_system'] = socket_data['store_system']/data.storages.length
                socket_data['store_cap'] = socket_data['store_cap']/data.storages.length
                socket_data['temp'] = (socket_data['temp']/data.storages.length) + (Math.random())*5
                socket_data['storages'] = data.storages
            socket_data
        catch e
            socket_data
            console.log e###
            
    server_stores: (server) =>
        store = []
        ((store.push {"node":i.cid,"ip":i.ip,"location":i.sid}) for i in @clouds.items when i.master is server.ip and i.cid isnt 0)
        store
        
    store_servers:(store) =>
        [{"ip":store.export}]
        
    colony_list:(machines) =>
        tmp = []
        tmp_client = []
        for i in machines
            if i.devtype is "export"
                tmp.push {"ip":i.ip,"chinese_type":"服务器","status":i.status}
            else if i.devtype is "storage"
                tmp.push {"ip":i.ip,"chinese_type":"存储","status":i.status}
            else
                tmp_client.push i.ip
                
        for i in tmp
            if i.ip in tmp_client
                i.client = true
            else
                i.client = false
        tmp
            
    feed_event: (e) =>
        console.log e
        events = ["disk.plugged","disk.unplugged","raid.created","volume.created", \
                       "volume.removed","raid.removed","raid.failed","volume.failed","raid.degraded"]
        try
            switch e.event
                when "ping.offline"
                    @_tooltips(e.ip,"掉线了")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    $(this).triggerHandler "offline", e.machineId
                when "ping.online"
                    @_tooltips(e.ip,"上线了")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    $(this).triggerHandler "online", e.machineId
                when "disk.unplugged"
                    @_tooltips(e.ip,"掉盘了")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
    
                when "raid.degraded", "raid.failed"
                    @_tooltips(e.ip,"有阵列损坏")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "volume.failed"
                    @_tooltips("e.ip","有虚拟磁盘损坏")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "safety.created"
                    @_tooltips("","已切换到数据保险箱")
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                 
                ###########################################################
                when "raid.created","volume.created", "volume.removed","raid.removed"
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "disk.ioerror", "disk.formated", "disk.plugged"
                    @_update_queue.push @centers
                    @_update_queue.push @journals
                    @_update_queue.push @stores
                    @_update_queue.push @stats
                    @_update_queue.push @disks
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "disk.role_changed"
                    @_update_queue.push @disks
                    @_update_queue.push @raids
                    @_update_queue.push @journals
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "raid.normal"
                    @_update_queue.push @raids
                    @_update_queue.push @journals
                    @_update_queue.push @machinedetails
                    @_update_queue.push @colonys
                    
                when "raid.rebuild"
                    raid = @raids.get e.raid
                    if raid != undefined
                        raid.rebuilding = e.rebuilding
                        raid.health = e.health
                        raid.rebuild_progress = e.rebuild_progress
                        $(this).triggerHandler "raid", raid 
                        
                when "raid.rebuild_done"
                    raid = @raids.get e.raid
                    if raid != undefined
                        raid.rebuilding = e.rebuilding
                        raid.health = e.health
                        raid.rebuild_progress = e.rebuild_progress
                        $(this).triggerHandler "raid", raid
                        @_update_queue.push @disks
                        
                when "raid.rqr"
                    raid = @raids.get e.raid
                    raid.rqr_count = e.rqr_count
                    $(this).triggerHandler "raid", raid
                    
                when "notification"
                    $(this).triggerHandler "notification", e
                when "user.login"
                    $(this).triggerHandler "user_login", e.login_id
                
                when "cmd.client.change"
                    @_update_queue.push @clouds
                    @_update_queue.push @colonys
                    $(this).triggerHandler "ClientChange", e
                    
                when "cmd.storage.build"
                    @_update_queue.push @colonys
                    $(this).triggerHandler "CreateFilesystem", e
        catch e
            return
                
    _tooltips:(ip,type) =>
        $(`function(){
            $.extend($.gritter.options, {
                class_name: 'gritter', 
                position: 'bottom-right', 
                fade_in_speed: 100, 
                fade_out_speed: 100, 
                time: 30000 
            });
            $.gritter.add({
                title: '<i class="icon-bell">告警信息</i>',
                text: '<a href="#" style="color:#ccc;font-size:14px;">' + ip + type + '</a><br>已发送邮件告警.'
            });
            return false;
        }`)
    
    update: (res, errc) =>
        chain = new Chain errc
        chain.chain(($.map @_deps[res], (name) => (=> this[name].update())))
        chain

    _update_loop: =>
        @_looper_id = setInterval((=>
            @_update_queue = unique @_update_queue
            @_update_queue[0].update?() if @_update_queue[0]?
            @_update_queue = @_update_queue[1...]
            return
            ), 1000)

    close_socket: =>
        try
            @socket_event.disconnect()
            #@socket_statist.disconnect()
            @ws.close()
            clearInterval @_looper_id if @_looper_id?
            NProgress.start()
            setTimeout (=> NProgress.done();$('.fade').removeClass('out')),100
            $(".page-content").css("background-color","#364150")
            $('.menu-toggler').attr('style', 'display:none')
            ((window.clearInterval(i)) for i in global_Interval)
            if global_Interval.length
                global_Interval.splice(0,global_Interval.length)
            if $('body').hasClass("page-sidebar-closed")
                $('body').removeClass("page-sidebar-closed")
            return
        catch e
            return

    disconnect_listener: =>
        $(this).triggerHandler "disconnect", @host

this.Chain = Chain
this.StorageData = StorageData
this.CentralStorageData = CentralStorageData