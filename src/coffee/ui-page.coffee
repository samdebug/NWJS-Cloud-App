class Page extends AvalonTemplUI
    constructor: (prefix, src, attr={}) ->
        super prefix, src, ".page-content", true, attr
        
class DetailTablePage extends Page
    constructor: (prefix, src) ->
        super prefix, src
        

    detail: (e) =>
        if not @has_rendered
            return
        tr = $(e.target).parents("tr")[0]
        res = e.target.$vmodel.$model.e
        if @data_table.fnIsOpen tr
            $("div", $(tr).next()[0]).slideUp =>
                @data_table.fnClose tr
                res.detail_closed = true
                close_detial? res
                delete avalon.vmodels[res.id]
        else
            try
                res.detail_closed = false
                console.log res
                [html,vm] = @detail_html res
                row = @data_table.fnOpen tr, html, "details"
                avalon.scan row, vm
                $("div", row).slideDown()
            catch e
                console.log e

class OverviewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "overviewpage-", "html/overviewpage.html"
        @flow_max = 0

        $(@sd.disks).on "updated", (e, source) =>
            disks = []
            
            for i in source.items
                if i.health == "normal"
                    disks.push i
            @vm.disk_num = disks.length
            
        $(@sd.raids).on "updated", (e, source) =>
            @vm.raid_num = source.items.length
        $(@sd.volumes).on "updated", (e, source) =>
            @vm.volume_num = source.items.length
        $(@sd.initrs).on "updated", (e, source) =>
            @vm.initr_num = source.items.length

        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.cpu
                @vm.mem_load  = parseInt latest.mem
                @vm.temp_load = parseInt latest.temp
                @refresh_flow()

        $(@sd.journals).on "updated", (e, source) =>
            @vm.journals = @add_time_to_journal source.items[..]

    define_vm: (vm) =>
        vm.lang = lang.overviewpage
        vm.disk_num = 0
        vm.raid_num = 0
        vm.volume_num = 0
        vm.initr_num = 0
        vm.cpu_load = 0
        vm.mem_load = 0
        vm.temp_load = 0
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered

        vm.switch_flow_type = (e) =>
            v = $(e.target).data("flow-type")                 #make sure to show fread_mb or fwrite_mb
            vm.flow_type = v
            @flow_max = 0
        vm.switch_to_page = @switch_to_page
        
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "temp_load", (nval, oval) =>
            $("#temp-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        
    rendered: () =>
        super()
        opt = animate: 1000, size: 128, lineWidth: 10, lineCap: "butt", barColor: ""
        opt.barColor = App.getLayoutColorCode "green"
        $("#cpu-load").easyPieChart opt
        $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
        $("#mem-load").easyPieChart opt
        $("#mem-load").data("easyPieChart").update? @vm.mem_load
        $("#temp-load").easyPieChart opt
        $("#temp-load").data("easyPieChart").update? @vm.temp_load

        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: false

        [max, ticks] = @flow_data_opt()
        @plot_flow max, ticks

    flow_data_opt: () =>
        type = @flow_type()
        #type = @vm.flow_type
        #other_type = @combine_type()
        #flow_peak = Math.max(((sample[type] + sample[other_type]) for sample in @sd.stats.items)...)
        flow_peak = Math.max((sample[type] for sample in @sd.stats.items)...)
        if flow_peak < 10
            opts = ({peak: 3+3*i, max: 6+3*i, ticks:[0, 2+1*i, 4+2*i, 6+3*i]} for i in [0..4])
        else
            opts = ({peak: 30+30*i, max: 60+30*i, ticks:[0, 20+10*i, 40+20*i, 60+30*i]} for i in [0..40])
        for {peak, max, ticks} in opts
            if flow_peak < peak
                break
        return [max, ticks]

    flow_data: () =>
        type = @flow_type()
        # type = @vm.flow_type
        #other_type = @combine_type()
        offset = 120 - @sd.stats.items.length
        #data = ([i+offset, (sample[type] + sample[other_type])] for sample, i in @sd.stats.items)
        data = ([i+offset, sample[type]] for sample, i in @sd.stats.items)
        zero = [0...offset].map (e) -> [e, 0]
        zero.concat data

    flow_type: =>
        feature = @sd.systeminfo.data.feature
        rw = if @vm.flow_type is "fwrite_mb" then "write" else "read"
        if "monfs" in feature
            return "f#{rw}_mb"
        else if "xfs" in feature
            return "n#{rw}_mb"
        else
            return "#{rw}_mb"

    add_time_to_journal:(items) =>
            journals = []
            change_time = `function funConvertUTCToNormalDateTime(utc)
            {
                var date = new Date(utc);
                var ndt;
                ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
                return ndt;
            }`
            for item in items
                localtime = change_time(item.created_at*1000)
                item.message =  "[#{localtime}]  #{item.message}"
                journals.push item
            return journals
            
    combine_type: ->
        if @vm.flow_type[0] is "f"
            type = @vm.flow_type.slice 1
        else
            type = "f" + @vm.flow_type
        type

    plot_flow: (max, ticks) =>
        @$flow_stats = $.plot $("#flow_stats"), [@flow_data()],
            series:
                shadowSize: 1
            lines:
                show: true
                lineWidth: 0.2
                fill: true
                fillColor:
                    colors: [
                        {opacity: 0.1}
                        {opacity: 1}
                    ]
            yaxis:
                min: 0
                max: max
                tickFormatter: (v) -> "#{v}MB"
                ticks: ticks
            xaxis:
                show: false
            colors: ["#6ef146"]
            grid:
                tickColor: "#a8a3a3"
                borderWidth: 0

    refresh_flow: () =>
        [max, ticks] = @flow_data_opt()
        if max is @flow_max
            @$flow_stats.setData [@flow_data()]
            @$flow_stats.draw()
        else
            @flow_max = max
            @plot_flow(max, ticks)

class DiskPage extends Page
    constructor: (@sd) ->
        super "diskpage-", "html/diskpage.html"
        $(@sd.disks).on "updated", (e, source) =>
            @vm.disks = @subitems()
            @vm.need_format = @need_format()
            @vm.slots = @get_slots()
            @vm.raids = @get_raids()
        console.log "diskssssssssssss"
        console.log @vm.raids
        console.log @vm.disks                    

    define_vm: (vm) =>
        vm.disks = @subitems()
        vm.slots = @get_slots()
        vm.raids = @get_raids()
        vm.lang = lang.diskpage
        vm.fattr_health = fattr.health
        vm.fattr_role = fattr.role
        vm.fattr_host = fattr.host
        vm.fattr_cap = fattr.cap
        vm.fattr_import = fattr._import
        vm.fattr_disk_status = fattr.disk_status
        vm.fattr_raid_status = fattr.raid_status
        vm.format_disk = @format_disk
        vm.format_all = @format_all
        vm.need_format = @need_format()
        
        vm.disk_list = @disk_list
        
    rendered: () =>
        super()
        $("[data-toggle='tooltip']").tooltip()
        $ ->
        $("#myTab li:eq(0) a").tab "show"

    subitems: () =>
        subitems @sd.disks.items,location:"",host:"",health:"",raid:"",role:"",cap_sector:""

    get_slots: () =>
        console.log @sd.dsus.items
        console.log @sd.disks.items
        console.log @subitems()
        slotgroups = []
        slotgroup = []

        dsu_disk_num = 0
        raid_color_map = @_get_raid_color_map()
        for dsu in @sd.dsus.items
            for i in [1..dsu.support_disk_nr]
                o = @_has_disk(i, dsu, dsu_disk_num)
                o.raidcolor = raid_color_map[o.raid]
                o.info = @_get_disk_info(i, dsu)
                slotgroup.push o
                if i%4 is 0
                    slotgroups.push slotgroup
                    slotgroup = []
            dsu_disk_num = dsu_disk_num + dsu.support_disk_nr

        console.log slotgroups
        return slotgroups

    get_raids: () =>
        raids = []
        raid_color_map = @_get_raid_color_map()
        for key, value of raid_color_map
            o = name:key, color:value
            raids.push o
        return raids

    disk_list: (disks) =>
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)

    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', \
        'kicked':'损坏', 'global_spare':'全局热备盘', 'data&spare':'数据热备盘'}
        type = {'enterprise': '企业盘', 'monitor': '监控盘', 'sas': 'SAS盘'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length == 0
                        val = '无'
                    status += '阵列: ' + val + '<br/>'
                when 'vendor'
                    status += '品牌: ' + val + '<br/>'
                when 'sn'
                    status += '序列号: ' + val + '<br/>'
                when 'model'
                    status += '型号: ' + val + '<br/>'
                when 'type'
                    name = '未知'
                    mod = obj.model.match(/(\S*)-/)[1];
                    $.each disks_type, (j, k) ->
                        if mod in k
                            name = type[j]
                    status += '类型: ' + name + '<br/>'
                    
        status
        
    _get_disk_info: (slotNo, dsu) =>
        for disk in @sd.disks.items
            if disk.location is "#{dsu.location}.#{slotNo}"
                info = health:disk.health, cap_sector:disk.cap_sector, \
                role:disk.role, raid:disk.raid, vendor:disk.vendor, \
                sn:disk.sn, model:disk.model, type:disk.type
                return info
        'none'
        
    _has_disk: (slotNo, dsu, dsu_disk_num) =>
        loc = "#{dsu_disk_num + slotNo}"
        for disk in @subitems()
            if disk.location is "#{dsu.location}.#{slotNo}"
                rdname = if disk.raid is ""\
                    then "noraid"\
                    else disk.raid
                rdrole = if disk.health is "down"\
                    then "down"\
                    else disk.role
                o = slot: loc, role:rdrole, raid:rdname, raidcolor: ""
                return o
        o = slot: loc, role:"nodisk", raid:"noraid", raidcolor: ""
        return o

    _get_raid_color_map: () =>
        map = {}
        raids = []
        i = 1
        has_global_spare = false
        for disk in @subitems()
            if disk.role is "global_spare"
                has_global_spare = true
                continue
            rdname = if disk.raid is ""\
                then "noraid"\
                else disk.raid
            if rdname not in raids
                raids.push rdname
        for raid in raids
            map[raid] = "color#{i}"
            i = i + 1
        map["noraid"] = "color0"
        if has_global_spare is true
            map["global_spare"] = "color5"
        return map

    format_disk: (element) =>
        if element.host is "native"
            return
        (new ConfirmModal lang.diskpage.format_warning(element.location), =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new DiskRest @sd.host).format element.location
            chain.chain @sd.update("disks")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()

    format_all: =>
        disks = @_need_format_disks()
        (new ConfirmModal lang.diskpage.format_all_warning, =>
            @frozen()
            chain = new Chain
            rest = new DiskRest @sd.host
            i = 0
            for disk in disks
                chain.chain ->
                    (rest.format disks[i].location).done -> i += 1
            chain.chain @sd.update("disks")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()

    need_format: =>
        return if (@_need_format_disks()).length isnt 0 then true else false

    _need_format_disks: =>
        disks = @subitems()
        needs = (disk for disk in disks when disk.host isnt "native")

class RaidPage extends DetailTablePage
    constructor: (@sd) ->
        super "raidpage-", "html/raidpage.html"

        table_update_listener @sd.raids, "#raid-table", =>
            @vm.raids = @subitems() if not @has_frozen

        $(@sd).on "raid", (e, raid) =>
            for r in @sd.raids.items
                if r.id is raid.id
                    r.health = raid.health
                    r.rqr_count = raid.rqr_count
                    r.rebuilding = raid.rebuilding
                    r.rebuild_progress = raid.rebuild_progress
            for r in @vm.raids
                if r.id is raid.id
                    r.rqr_count = raid.rqr_count
                    if r.rebuilding and raid.health == 'normal'
                        count = 5
                        delta = (1-r.rebuild_progress) / count
                        i = 0
                        tid = setInterval (=>
                            if i < 5
                                r.rebuild_progress += delta
                                i+=1
                            else
                                clearInterval tid
                                r.health = raid.health
                                r.rebuilding = raid.rebuilding
                                r.rebuild_progress = raid.rebuild_progress), 800
                    else
                        r.health = raid.health
                        r.rebuilding = raid.rebuilding
                        r.rebuild_progress = raid.rebuild_progress

    define_vm: (vm) =>
        vm.raids = @subitems()
        vm.lang = lang.raidpage
        vm.fattr_health = fattr.health
        vm.fattr_rebuilding = fattr.rebuilding
        vm.fattr_cap_usage = fattr.cap_usage_raid
        vm.all_checked = false

        vm.detail = @detail
        vm.create_raid = @create_raid
        vm.delete_raid = @delete_raid
        vm.set_disk_role = @set_disk_role

        vm.$watch "all_checked", =>
            for r in vm.raids
                r.checked = vm.all_checked

    subitems: () =>
        subitems(@sd.raids.items, id:"", name:"", level:"", chunk_kb:"",\
            health:"", rqr_count:"", rebuilding:"", rebuild_progress:0,\
            cap_sector:"", used_cap_sector:"", detail_closed:true, checked:false)

    rendered: () =>
        @vm.raids = @subitems() if not @has_frozen
        super()

        @data_table = $("#raid-table").dataTable(
            sDom: 't'
            oLanguage:
                sEmptyTable: "没有数据")

    detail_html: (raid) =>
        html = avalon_templ raid.id, "html/raid_detail_row.html"
        o = @sd.raids.get raid.id
        vm = avalon.define raid.id, (vm) =>
            vm.disks = subitems @sd.raid_disks(o),location:"",health:"",role:""
            vm.lang  = lang.raidpage.detail_row
            vm.fattr_health = fattr.health
            vm.fattr_role   = fattr.role

        $(@sd.disks).on "updated.#{raid.id}", (e, source) =>
            vm.disks = subitems @sd.raid_disks(o),location:"",health:"",role:""
        return [html, vm]

    close_detial: (raid) =>
        $(@sd.disks).off ".#{raid.id}"

    set_disk_role: () =>
        if @sd.raids.items.length > 0
            (new RaidSetDiskRoleModal(@sd, this)).attach()
        else
            (new MessageModal(lang.raid_warning.no_raid)).attach()

    create_raid: () =>
        (new RaidCreateModal(@sd, this)).attach()

    delete_raid: () =>
        deleted = ($.extend({},r.$model) for r in @vm.raids when r.checked)
        if deleted.length isnt 0
            (new RaidDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(lang.raid_warning.no_deleted_raid)).attach()

class VolumePage extends DetailTablePage
    constructor: (@sd) ->
        super "volumepage-", "html/volumepage.html"
        table_update_listener @sd.volumes, '#volume-table', =>
            @vm.volumes = @subitems() if not @has_frozen
        table_update_listener @sd.filesystem, '#volume-table', =>
            @vm.volumes = @subitems() if not @has_frozen
        $(@sd.systeminfo).on "updated", (e, source) =>
            feature = @sd.systeminfo.data.feature
            @vm.show_fs = if "monfs" in feature or "xfs" in feature then true else false
            @fs_type = if "monfs" in feature then "monfs" else if "xfs" in feature then "xfs"
            @vm.show_cap = if "xfs" in feature then true else false
            @vm.show_cap_new = if "monfs" in feature or "ipsan" in feature then true else false
            @vm.show_precreate = if "monfs" in feature or "xfs" in feature and @_settings.znv then true else false
       
        @show_chosendir = @_settings.chosendir      #cangyu varsion can choose the target directory to mount
         
        failed_volumes = []
        @lock = false
        $(@sd).on "volume", (e, volume) =>
            @lock = volume.syncing
            if @_settings.sync
                if volume.event == "volume.created"
                    @lock = true
                else if volume.event == "volume.sync_done"
                    @lock = false                    
            for r in @sd.volumes.items
                if r.id is volume.id
                    r.sync_progress = volume.sync_progress
                    r.sync = volume.syncing
                    r.event = volume.event
            for r in @vm.volumes
                if r.id is volume.id
                    r.sync_progress = volume.sync_progress
                    r.syncing = volume.syncing
                    r.event = volume.event                               
                    r.sync = volume.syncing
                    
            real_failed_volumes = []
            if volume.event == "volume.failed"
                volume = @sd.volumes.get e.uuid
                failed_volumes.push r
            for i in @sd.volumes.items
                if i.health == "failed"
                    real_failed_volumes.push i
            if failed_volumes.length == real_failed_volumes.length and failed_volumes.length
                (new SyncDeleteModal(@sd, this, real_failed_volumes)).attach()
                failed_volumes = []
                return

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        vm.volumes = @subitems()
        vm.lang = lang.volumepage
        vm.fattr_health = fattr.health
        vm.fattr_cap = fattr.cap
        vm.fattr_precreating = fattr.precreating        
        vm.detail = @detail
        vm.all_checked = false
        vm.create_volume = @create_volume
        vm.delete_volume = @delete_volume
        vm.enable_fs  = @enable_fs
        vm.disable_fs = @disable_fs
        vm.fattr_synchronizing = fattr.synchronizing
        vm.fattr_cap_usage_vol = fattr.cap_usage_vol
        
        vm.show_sync = @_settings.sync
        vm.enable_sync = @enable_sync
        vm.pause_synv = @pause_sync
        vm.disable_sync = @disable_sync      
        vm.sync_switch = @sync_switch
        
        vm.show_fs = @show_fs
        
        
        vm.show_precreate = @show_precreate
        vm.pre_create = @pre_create
        vm.server_start = @server_start
        vm.server_stop = @server_stop
        
        vm.show_cap = @show_cap
        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked


    subitems: () =>
        items = subitems @sd.volumes.items, id:"", name:"", health:"", cap_sector:"",\
             used:"", detail_closed:true, checked:false, fs_action:"enable",\
             syncing:'', sync_progress: 0, sync:'', precreating:"",\
             precreate_progress: "", precreate_action:"unavail", event: ""     
        for v in items
            if v.used
                v.fs_action = "disable"
                v.precreate_action = "precreating"
                if v.precreating isnt true and v.precreate_progress == 0
                    v.precreate_action = "enable_precreate"                   
            else
                v.fs_action = "enable"
                v.precreate_action = "unavail"                        
        return items  
        
    rendered: () =>
        super()
        @vm.volumes = @subitems() if not @has_frozen
        @data_table = $("#volume-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
    
    detail_html: (volume) =>
        html = avalon_templ volume.id, "html/volume_detail_row.html"
        o = @sd.volumes.get volume.id
        vm = avalon.define volume.id, (vm) =>
            vm.initrs = subitems @sd.volume_initrs(o),active_session:"",wwn:""
            vm.lang = lang.volumepage.detail_row
            vm.fattr_active_session = fattr.active_session

        $(@sd.initrs).on "updated.#{volume.id}", (e, source) =>
            vm.initrs = subitems @sd.volume_initrs(o),active_session:"",wwn:""
        return [html, vm]

    close_detial: (volume) =>
        $(@sd.initrs).off ".#{volume.id}"

    create_volume: () =>
        if @lock
            volume_syncing = []
            for i in @subitems()
                if i.syncing == true
                    volume_syncing.push i.name        
            (new MessageModal lang.volumepage.th_syncing_warning(volume_syncing)).attach()
            return
            
        raids_available = []
        for i in @sd.raids.items
            if i.health == "normal"
                raids_available.push i
        
        if raids_available.length > 0
            
            (new VolumeCreateModal(@sd, this)).attach()
        else
            (new MessageModal(lang.volume_warning.no_raid)).attach()

    delete_volume: () =>
        
        ###
        deleted = ($.extend({},v.$model) for v in @vm.volumes when v.checked)
        lvs_with_fs = []
        for fs_o in @sd.filesystem.data
            lvs_with_fs.push fs_o.volume

        for v in deleted
            if v.used
                if v.name in lvs_with_fs
                    (new MessageModal(lang.volume_warning.fs_on_volume(v.name))).attach()
                else if @sd.volume_initrs(v).length isnt 0
                    (new MessageModal(lang.volume_warning.volume_mapped_to_initrs(v.name))).attach()
                return
            else if @lock
                volume_syncing = []
                for i in @subitems()
                    if i.syncing == true
                        volume_syncing.push i.name             
                (new MessageModal lang.volumepage.th_syncing_warning(volume_syncing)).attach()
                return
        if deleted.length isnt 0
            (new VolumeDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(lang.volume_warning.no_deleted_volume)).attach()
###
    _apply_fs_name: () =>
        max = @_settings.fs_max
        used_names=[]
        availiable_names=[]
        for fs_o in @sd.filesystem.data
            used_names.push fs_o.name
        for i in [1..max]
            if "myfs#{i}" in used_names
                continue
            else
                availiable_names.push "myfs#{i}"

        if availiable_names.length is 0
            return ""
        else
            return availiable_names[0]

    enable_fs: (v) =>
        if @sync
            (new MessageModal lang.volumepage.th_syncing_warning).attach()
            return
        fs_name = @_apply_fs_name()
        feature = @sd.systeminfo.data.feature[0]
        
        if v.used
            (new MessageModal(lang.volume_warning.volume_mapped_to_fs(v.name))).attach()
        else if fs_name is "" 
            if 'monfs' == feature 
                (new MessageModal(lang.volume_warning.only_support_one_fs)).attach()
            else if 'xfs' == feature
                (new MessageModal(lang.volume_warning.over_max_fs)).attach()
        else if @show_chosendir
            (new FsCreateModal(@sd, this, v.name)).attach()
        else if @_settings.znv
            (new FsChooseModal(@sd, this, fs_name, v.name)).attach()            
        else
            (new ConfirmModal(lang.volume_warning.enable_fs, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new FileSystemRest(@sd.host)).create fs_name, @fs_type, v.name)
                    .chain @sd.update("filesystem")
                show_chain_progress(chain).done =>
                    @attach()
                .fail (data)=>
                    (new MessageModal(lang.volume_warning.over_max_fs)).attach()
                    @attach())).attach()
                    
    disable_fs: (v) =>
        if @sync
            (new MessageModal lang.volumepage.th_syncing_warning).attach()
            return

        fs_name = ""
        for fs_o in @sd.filesystem.data
            if fs_o.volume is v.name
                fs_name = fs_o.name
                break

        (new ConfirmModal(lang.volume_warning.disable_fs, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new FileSystemRest(@sd.host)).delete fs_name)
                .chain @sd.update("filesystem")
            show_chain_progress(chain).done =>
                @attach())).attach()

    sync_switch: (v) =>
        console.log v
        if v.syncing
            @disable_sync(v)
        else
            @enable_sync(v)           

            
    enable_sync: (v) =>
        if v.health != 'normal'
            (new MessageModal lang.volume_warning.disable_sync).attach()
            return    
        (new ConfirmModal(lang.volume_warning.enable_sync(v.name), =>
            @frozen()
            chain = new Chain()
            chain.chain => 
                (new SyncConfigRest(@sd.host)).sync_enable(v.name)
            show_chain_progress(chain,true).done =>
                @attach()
            .fail (data) =>
                (new MessageModal lang.volume_warning.syncing_error).attach()
            )).attach()               
                #(new MessageModal lang.volumepage.syncing).attach())

    disable_sync: (v) =>
        chain = new Chain()
        chain.chain => 
            (new SyncConfigRest(@sd.host)).sync_disable(v.name)
        (show_chain_progress chain).done =>
            @attach()
        .fail (data) =>
            (new MessageModal lang.volume_warning.syncing_error).attach()

    pre_create: (v) =>
        chain = new Chain
        chain.chain(=> (new ZnvConfigRest(@sd.host)).precreate v.name)
         #   .chain @sd.update("volumes")
        (show_chain_progress chain).done 

    server_start: (bool) =>
        chain = new Chain
        chain.chain =>
            (new ZnvConfigRest(@sd.host)).start_service(bool)
        (show_chain_progress chain).done =>
            (new MessageModal lang.volumepage.btn_enable_server).attach()

    server_stop: (bool) =>
        chain = new Chain
        chain.chain =>
            (new ZnvConfigRest(@sd.host)).stop_service(bool)
        (show_chain_progress chain).done (data)=>
            (new MessageModal lang.volumepage.btn_disable_server).attach()
            
class InitrPage extends DetailTablePage
    constructor: (@sd) ->
        super "initrpage-", "html/initrpage.html"

        table_update_listener @sd.initrs, "#initr-table", =>
            @vm.initrs = @subitems() if not @has_frozen

        $(@sd).on "initr", (e, initr) =>
            for i in @vm.initrs
                if i.id is initr.id
                    i.active_session = initr.active_session

        @vm.show_iscsi = if @_iscsi.iScSiAvalable() and !@_settings.fc then true else false

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        @_iscsi = new IScSiManager
        vm.initrs = @subitems()
        vm.lang = lang.initrpage
        vm.fattr_active_session = fattr.active_session
        vm.fattr_show_link = fattr.show_link
        vm.detail = @detail
        vm.all_checked = false

        vm.create_initr = @create_initr
        vm.delete_initr = @delete_initr

        vm.map_volumes = @map_volumes
        vm.unmap_volumes = @unmap_volumes

        vm.show_iscsi = @show_iscsi
        vm.link_initr = @link_initr
        vm.unlink_initr = @unlink_initr
        
        vm.$watch "all_checked", =>
            for v in vm.initrs
                v.checked = vm.all_checked
    
    subitems: () =>
        arrays = subitems @sd.initrs.items, id:"", wwn:"", active_session:"",\
            portals:"", detail_closed:true, checked:false 
        for item in arrays
            item.name = item.wwn
            item.iface = (portal for portal in item.portals).join ", "
        return arrays

    rendered: () =>
        @vm.initrs = @subitems()
        @data_table = $("#initr-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        super()

    detail_html: (initr) =>
        html = avalon_templ initr.id, "html/initr_detail_row.html"
        o = @sd.initrs.get initr.id
        vm = avalon.define initr.id, (vm) =>
            vm.volumes = subitems @sd.initr_volumes(o),name:""
            vm.lang = lang.initrpage.detail_row
        return [html, vm]

    create_initr: () =>   
        (new InitrCreateModal @sd, this).attach()

    delete_initr: () =>
        selected = ($.extend({},i.$model) for i in @vm.initrs when i.checked)
        initrs = (@sd.initrs.get initr.id for initr in selected)
        if initrs.length == 0
            (new MessageModal lang.initr_warning.no_deleted_intir).attach()
        else
            for initr in initrs
                volumes = @sd.initr_volumes initr
                if volumes.length isnt 0
                    (new MessageModal lang.initr_warning.intitr_has_map(initr.wwn)).attach()
                    return
            (new InitrDeleteModal @sd, this, selected).attach()

    map_volumes: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        volumes = []
        for i in @sd.volumes.items
            if i.health == "normal"
                volumes.push i
        if volumes.length == 0
            (new MessageModal lang.initr_warning.no_spared_volume).attach()
        else if selected.active_session
            (new MessageModal lang.initr_warning.detect_iscsi(selected.wwn)).attach()
        else
            (new VolumeMapModal @sd, this, selected).attach()

    unmap_volumes: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        volumes = @sd.initr_volumes selected
        if volumes.length == 0
            (new MessageModal lang.initr_warning.no_attached_volume).attach()
        else if selected.active_session
            (new MessageModal lang.initr_warning.unmap_iscsi(selected.wwn)).attach()
        else
            (new VolumeUnmapModal @sd, this, selected).attach()

    link_initr: (index) =>
        for indexs in [0..@vm.initrs.length-1] when @sd.initrs.items[indexs].active_session is true
            (new MessageModal lang.initr_warning.intitr_has_link).attach()
            return
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr
            @_iscsi.linkinit selected.wwn,portal.ipaddr
        (new ConfirmModal_link(
                lang.initr_link_warning.confirm_link(selected.wwn), =>
                    chain = new Chain()
                    @_iscsi_link index
            )).attach()

    unlink_initr: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr
            @_iscsi.linkinit selected.wwn,portal.ipaddr
        (new ConfirmModal_unlink(
                lang.initr_link_warning.undo_link(selected.wwn), =>
                    chain = new Chain()
                    @_iscsi_unlink index
            )).attach()

    _iscsi_link: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr 
        @frozen()
        chain = new Chain()
        chain.chain @sd.update('initrs')
        show_chain_progress(chain).done =>
            if @_iscsi.connect selected.wwn, portals
                @attach()
            else
                (new MessageModal(lang.initr_link_warning.link_err)).attach()
                @attach()
        .fail =>
            @attach()
        chains = new Chain()
        chains.chain @sd.update('initrs')

    _iscsi_unlink: (index) =>
        selected = @sd.initrs.get @vm.initrs[index].id
        portals = []
        for portal in @sd.networks.items when portal.id in selected.portals
            portals.push portal.ipaddr 
        @frozen()
        chain = new Chain()
        chain.chain @sd.update('initrs')
        show_chain_progress(chain).done =>
            if @_iscsi.disconnect selected.wwn, portals
                @attach()
            else
                (new MessageModal(lang.initr_link_warning.link_err)).attach()
                @attach()
        .fail =>
            @attach()
        chains = new Chain()
        chains.chain @sd.update('initrs')
        
            
class SettingPage extends Page
    constructor: (@dview, @sd) ->
        super "settingpage-", "html/settingpage.html"
        @edited = null
        @settings = new SettingsManager
        $(@sd.networks).on "updated", (e, source) =>
            @vm.ifaces = @subitems()
            @vm.able_bonding = @_able_bonding()
            @vm.local_serverip = @sd.networks.items[1].ipaddr
            
        $(@sd.gateway).on "updated", (e, source) =>
            @vm.gateway = @sd.gateway.data.gateway

        @vm.server_options = [
          { value: "store_server", msg: "存储服务器" }
          { value: "forward_server", msg: "转发服务器" }
        ]
        
    #znv_server
               
    define_vm: (vm) =>
        @_settings = new (require("settings").Settings) 
        vm.lang = lang.settingpage
        vm.ifaces = @subitems()
        vm.gateway = @sd.gateway.data.gateway
        vm.old_passwd = ""
        vm.new_passwd = ""
        vm.confirm_passwd = ""
        vm.submit_passwd = @submit_passwd
        vm.keypress_passwd = @keypress_passwd
        vm.edit_iface = (e) =>
            for i in @vm.ifaces
                i.edit = false
            e.edit = true
            @edited = e
        vm.cancel_edit_iface = (e) =>
            e.edit = false
            @edited = null
            i = @sd.networks.get e.id
            e.ipaddr  = i.ipaddr
            e.netmask = i.netmask
        vm.submit_iface   = @submit_iface
        vm.submit_gateway = @submit_gateway
        vm.able_bonding = true
        vm.eth_bonding = @eth_bonding
        vm.eth_bonding_cancel = @eth_bonding_cancel
        
        vm.znv_server = @znv_server
        vm.server_options = ""
        vm.enable_server = true
        vm.server_switch = @_settings.znv
        vm.select_ct = true
        vm.serverid = ""
        vm.local_serverip = ""
        vm.local_serverport = "8003"
        vm.cmssverip = ""
        vm.cmssverport = "8000"
        vm.directory ="/nvr/d1;/nvr/d2"
                
    subitems: () =>
        items = subitems @sd.networks.items,id:"",ipaddr:"",iface:"",netmask:"",type:"",edit:false
        removable = []
        if not @_able_bonding()
            for eth in items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        items

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $.validator.addMethod("same", (val, element) =>
            if @vm.new_passwd != @vm.confirm_passwd
                return false
            else
                return true
        , "两次输入的新密码不一致")

        $("#server_select").chosen()
        chosen = $("#server_select")
        chosen.change =>
            if chosen.val() == "store_server"
                @vm.local_serverport = 8003
                @vm.select_ct = true
            else
                @vm.local_serverport = 8002
                @vm.select_ct = false
                
        $("form.passwd").validate(
            valid_opt(
                rules:
                    old_passwd:
                        required: true
                        maxlength: 32
                    new_passwd:
                        required: true
                        maxlength: 32
                    confirm_passwd:
                        required: true
                        maxlength: 32
                        same: true
                messages:
                    old_passwd:
                        required: "请输入您的旧密码"
                        maxlength: "密码长度不能超过32个字符"
                    new_passwd:
                        required: "请输入您的新密码"
                        maxlength: "密码长度不能超过32个字符"
                    confirm_passwd:
                        required: "请再次输入您的新密码"
                        maxlength: "密码长度不能超过32个字符"))

        Netmask = require("netmask").Netmask
        $.validator.addMethod("validIP", (val, element) =>
            regex = /^\d{1,3}(\.\d{1,3}){3}$/
            if not regex.test val
                return false
            try
                n = new Netmask(val)
                return true
            catch error
                return false
        )

        $.validator.addMethod("validport", (val, element) =>
            regex = /^[0-9]*$/
            if not regex.test val
                return false
            try
                n = new Netmask(val)
                return true 
            catch error
                return true                
        )
                
        $.validator.addMethod("samesubnet", (val, element) =>
            try
                subnet = new Netmask("#{@edited.ipaddr}/#{@edited.netmask}")
                for n in @sd.networks.items
                    if n.iface == @edited.iface
                        continue
                    if n.ipaddr isnt "" and subnet.contains n.ipaddr
                        return false
                return true
            catch error
                return false
        ,(params, element) =>
            try
                subnet = new Netmask("#{@edited.ipaddr}/#{@edited.netmask}")
                for n in @sd.networks.items
                    if n.iface == @edited.iface
                        continue
                    if n.ipaddr isnt "" and subnet.contains n.ipaddr
                        return "和#{n.iface}处在同一网段，请重新配置网卡"
            catch error
                return "网卡配置错误，请重新配置网卡"
        )
        
        $.validator.addMethod("using", (val, element) =>
            for initr in @sd.initrs.items
                if @edited.iface in initr.portals
                    return false
            return true
        ,(val, element) =>
            for initr in @sd.initrs.items
                if @edited.iface in initr.portals
                    return "客户端#{initr.wwn}正在使用#{@edited.iface}，请删除客户端，再配置网卡"
        )

        $("#network-table").validate(
            valid_opt(
                rules:
                    ipaddr:
                        required: true
                        validIP: true
                        samesubnet: true
                        using: true
                    netmask:
                        required: true
                        validIP: true
                messages:
                    ipaddr:
                        required: "请输入IP地址"
                        validIP: "无效IP地址"
                    netmask:
                        required: "请输入子网掩码"
                        validIP: "无效子网掩码"))

        $.validator.addMethod("reachable", (val, element) =>
            for n in @sd.networks.items
                try
                    subnet = new Netmask("#{n.ipaddr}/#{n.netmask}")
                catch error
                    # some ifaces have empty ipaddr, so ignore it
                    continue

                if subnet.contains val
                    return true
            return false
        )

        $("form.gateway").validate(
            valid_opt(
                rules:
                    gateway:
                        required: true
                        validIP: true
                        reachable: true
                messages:
                    gateway:
                        required: "请输入网关地址"
                        validIP: "无效网关地址"
                        reachable: "路由不在网卡网段内"))

        $("#server-table").validate(
            valid_opt(
                rules:
                    cmssverip:
                        required: true
                        validIP: true
                        reachable: true
                    cmssverport:
                        required: true
                        validport: true
                        #reachable: true
                messages:
                    cmssverip:
                        required: "请输入中心IP"
                        validIP: "无效IP地址"
                        reachable: "路由不在网卡网段内"
                    cmssverport:
                        required: "请输入监听端口"
                        validport: "无效端口"
                        #reachable: "端口不存在"
                        ))

        $("form.server").validate(
            valid_opt(
                rules:
                    serverid:
                        required: true
                        validport: true
                        #reachable: true
                    local_serverip:
                        required: true
                        validIP: true
                        reachable: true
                    local_serverport:
                        required: true
                        validport: true
                        #reachable: true
           
                messages:
                    serverid:
                        required: "请输入服务器ID"
                        validport: "无效服务器ID"
                        #reachable: "路由不在网卡网段内"                    
                    local_serverip:
                        required: "请输入本机IP"
                        validIP: "无效IP地址"
                        reachable: "路由不在网卡网段内"
                    local_serverport:
                        required: "请输入监听端口"
                        validport: "无效端口"
                        #reachable: "端口不存在"
                        ))

    submit_passwd: () =>
        if $("form.passwd").validate().form()
            if @vm.old_passwd is @vm.new_passwd
                (new MessageModal lang.settingpage.useradmin_error).attach()
            else
                chain = new Chain
                chain.chain =>
                    (new UserRest(@sd.host)).change_password("admin", @vm.old_passwd, @vm.new_passwd)

                (show_chain_progress chain).done =>
                    @vm.old_passwd = ""
                    @vm.new_passwd = ""
                    @vm.confirm_passwd = ""
                    (new MessageModal lang.settingpage.message_newpasswd_success).attach()


    keypress_passwd: (e) =>
        @submit_passwd() if e.which is 13

    submit_iface: (e) =>
        for portal in @sd.networks.items when portal.ipaddr is e.ipaddr
            (new MessageModal lang.settingpage.iface_error).attach()
            return
        if $("#network-table").validate().form()
            (new ConfirmModal(lang.network_warning.config_iface, =>
                e.edit = false
                @dview.reconnect = true
                chain = new Chain
                chain.chain =>
                    rest = new NetworkRest @sd.host
                    if e.type is "normal"
                        return rest.config e.iface,e.ipaddr,e.netmask
                    else if e.type is "bond-master"
                        return rest.modify_eth_bonding e.ipaddr, e.netmask
                show_chain_progress(chain, true).fail =>
                    index = window.adminview.find_nav_index @dview.menuid
                    window.adminview.remove_tab index if index isnt -1
            )).attach()

    submit_gateway: (e) =>
        if $("form.gateway").validate().form()
            (new ConfirmModal(lang.network_warning.config_gateway, =>
                chain = new Chain()
                chain.chain(=> (new GatewayRest(@sd.host)).config @vm.gateway)
                    .chain @sd.update("networks")
                show_chain_progress(chain).fail =>
                    @vm.gateway = @sd.gateway.ipaddr)).attach()

    znv_server: () =>
        if $("form.server").validate().form() and $("#server-table").validate().form()
            chain = new Chain
            chain.chain =>
                (new ZnvConfigRest(@sd.host)).znvconfig(@vm.select_ct, @vm.serverid, @vm.local_serverip, @vm.local_serverport, @vm.cmssverip, @vm.cmssverport, @vm.directory)
            (show_chain_progress chain).done =>
                (new MessageModal lang.settingpage.service_success).attach()

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    eth_bonding: =>
        if @_has_initr()
            (new MessageModal lang.settingpage.btn_eth_bonding_warning).attach()
            return
        else
            (new EthBondingModal @sd, this).attach()

    eth_bonding_cancel: =>
        if @_has_initr()
            (new MessageModal lang.settingpage.btn_eth_bonding_warning).attach()
            return
        else
            (new ConfirmModal lang.eth_bonding_cancel_warning, =>
                @frozen()
                @dview.reconnect = true
                chain = new Chain
                chain.chain =>
                    (new NetworkRest @sd.host).cancel_eth_bonding()
                show_chain_progress(chain, true).fail =>
                    index = window.adminview.find_nav_index @dview.menuid
                    window.adminview.remove_tab index if index isnt -1
            ).attach()
            return

    _has_initr: =>
        @sd.initrs.items.length isnt 0

class QuickModePage extends Page
    constructor: (@dview, @sd) ->
        super "quickmodepage-", "html/quickmodepage.html"
        @create_files = true
        $(@sd.systeminfo).on "updated", (e, source) =>
            feature = @sd.systeminfo.data.feature
            @vm.show_fs = if "monfs" in feature or "xfs" in feature then true else false

    define_vm: (vm) =>
        vm.lang = lang.quickmodepage
        vm.enable_fs = false
        vm.raid_name = ""
        vm.volume_name = ""
        vm.initr_wwn = ""
        #vm.chunk = "32KB"
        vm.submit = @submit

        @_iscsi = new IScSiManager
        vm.show_iscsi = @_iscsi.iScSiAvalable()
        @enable_iscsi = @_iscsi.iScSiAvalable()

        vm.$watch "volume_name", =>
            vm.initr_wwn = "#{prefix_wwn}:#{vm.volume_name}"

    count_dsu_disks: (dsu) =>
        return (disk for disk in @sd.disks.items\
                         when disk.role is 'unused'\
                         and disk.location.indexOf(dsu.location) is 0).length

    prefer_dsu_location: () =>
        for dsu in @sd.dsus.items
            if @count_dsu_disks(dsu) >= 3
                return dsu.location
        return if @sd.dsus.length then @sd.dsus.items[0].location else '_'

    rendered: () =>
        super()
        #$("[data-toggle='popover']").popover()
        $(".tooltips").tooltip()      
        [rd, lv, wwn] = @_get_unique_names()
        @vm.raid_name   = rd
        @vm.volume_name = lv
        @vm.initr_wwn   = wwn
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui")
        @dsuui.attach()
        @add_child @dsuui

        $("#enable-fs").change =>
            @vm.enable_fs = $("#enable-fs").prop "checked"
            if @vm.enable_fs
                @enable_iscsi = false
            else
                @enable_iscsi = $("#enable-iscsi").prop "checked"
        $("#create-files").change =>
            @create_files = $("#create-files").prop "checked"
        $("#enable-iscsi").change =>
            @enable_iscsi = $("#enable-iscsi").prop "checked"

        dsu = @prefer_dsu_location()
        [raids..., spares] = (disk for disk in @sd.disks.items\
                                when disk.role is 'unused'\
                                and disk.location.indexOf(dsu) is 0)
        spares = [] if not spares?
        if raids.length < 3 and spares
            raids = raids.concat spares
            spares = []
        @dsuui.check_disks raids
        @dsuui.check_disks spares, "spare"
        @dsuui.active_tab dsu

        console.log @dsuui.getchunk()

        $.validator.addMethod("min-raid-disks", (val, element) =>
            return @dsuui.get_disks().length >= 3
        )

        $("form", @$dom).validate(
            valid_opt(
                rules:
                    "raid":
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.raids.items
                        maxlength: 64
                    "volume":
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.volumes.items
                        maxlength: 64
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)(.*)$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    "raid-disks-checkbox":
                        "min-raid-disks": true
                        maxlength: 24
                messages:
                    "raid":
                        required: "请输入阵列名称"
                        duplicated: "阵列名称已存在"
                        maxlength: "阵列名称长度不能超过64个字母"
                    "volume":
                        required: "请输入虚拟磁盘名称"
                        duplicated: "虚拟磁盘名称已存在"
                        maxlength: "虚拟磁盘名称长度不能超过64个字母"
                    wwn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    "raid-disks-checkbox":
                        "min-raid-disks": "级别5阵列最少需要3块磁盘"
                        maxlength: "阵列最多支持24个磁盘"))

    _has_name: (name, res, nattr="name") =>
        for i in res.items
            if name is i[nattr]
                return true
        return false
    
    _all_unique_names: (rd, lv, wwn) =>
        return not (@_has_name(rd, @sd.raids) or @_has_name(lv, @sd.volumes) or @_has_name(wwn, @sd.initrs, "wwn"))

    _get_unique_names: () =>
        rd_name = "rd"
        lv_name = "lv"
        wwn = "#{prefix_wwn}:#{lv_name}"
        if @_all_unique_names rd_name, lv_name, wwn
            return [rd_name, lv_name, wwn]
        else
            i = 1
            while true
                rd = "#{rd_name}-#{i}"
                lv = "#{lv_name}-#{i}"
                wwn = "#{prefix_wwn}:#{lv}"
                if @_all_unique_names rd, lv, wwn
                    return [rd, lv, wwn]
                i += 1

    _get_ifaces: =>
        removable = []
        if not @_able_bonding()
            for eth in @sd.networks.items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        @sd.networks.items

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    submit: () =>
        if @dsuui.get_disks().length == 0
            (new MessageModal lang.quickmodepage.create_error).attach()
        else if @dsuui.get_disks().length <3
            (new MessageModal lang.quickmodepage.create_error_least).attach()
        else
            if $("form").validate().form()
                @create(@vm.raid_name, @dsuui.getchunk(), @dsuui.get_disks(), @dsuui.get_disks("spare"),\
                    @vm.volume_name, @vm.initr_wwn, @vm.enable_fs, @enable_iscsi, @create_files)

    create: (raid, chunk, raid_disks, spare_disks, volume, initr, enable_fs, enable_iscsi, create_files) =>
        raid_disks = raid_disks.join ","
        spare_disks = spare_disks.join ","

        for n in @_get_ifaces()
            if n.link and n.ipaddr isnt ""
                portals = n.iface
                break
        chain = new Chain
        chain.chain(=> (new RaidRest(@sd.host)).create(name: raid, level: 5,\
            chunk: chunk, raid_disks: raid_disks, spare_disks:spare_disks,\
            rebuild_priority:"", sync:"no", cache:""))
            .chain(=> (new VolumeRest(@sd.host)).create(name: volume,\
                raid: raid, capacity: "all"))
        if enable_fs
            chain.chain(=> (new FileSystemRest(@sd.host)).create "myfs", volume)
            ###
            if create_files
                chain.chain(=> (new CommandRest(@sd.host)).create_lw_files())
            ###
        else
            if not @sd.initrs.get initr
                chain.chain(=> (new InitiatorRest(@sd.host)).create(wwn:initr, portals:portals))
            chain.chain(=> (new InitiatorRest(@sd.host)).map initr, volume)
        chain.chain @sd.update("all")
        show_chain_progress(chain, false, false).done(=>
            if enable_iscsi
                ipaddr = (@sd.host.split ":")[0]
                @_iscsi_link initr, [ipaddr]
            if enable_fs and create_files
                setTimeout (new CommandRest(@sd.host)).create_lw_files, 1000
            @dview.switch_to_page "overview"
            @vm.enable_fs = false).fail(=>
            @vm.enable_fs = false)

    _iscsi_link: (initr, portals) ->
        try
            @_iscsi.connect initr, portals
        catch err
            console.log err

class MaintainPage extends Page
    constructor: (@dview, @sd) ->
        super "maintainpage-", "html/maintainpage.html"
        @settings = new SettingsManager
        $(@sd.systeminfo).on "updated", (e, source) =>
            @vm.server_version = "存储系统版本：#{@sd.systeminfo.data.version}"

    define_vm: (vm) =>
        _settings = new (require("settings").Settings)
        vm.lang = lang.maintainpage
        vm.diagnosis_url = "http://#{@sd.host}/api/diagnosis"
        vm.server_version = "存储系统版本：#{@sd.systeminfo.data.version}"
        vm.gui_version = "客户端版本：#{_settings.version}"
        vm.product_model = "产品型号：CYBX-4U24-T-DC"
        vm.poweroff = @poweroff
        vm.reboot = @reboot
        vm.sysinit = @sysinit
        vm.recover = @recover
        vm.scan_system = @scan_system
        vm.fs_scan = !_settings.sync
        vm.show_productmodel = _settings.product_model

    rendered: () =>
        super()
        $("#fileupload").fileupload(url:"http://#{@sd.host}/api/upgrade")
            .bind("fileuploaddone", (e, data) ->
                (new MessageModal(lang.maintainpage.message_upgrade_success)).attach())
        $("input[name=files]").click ->
            $("tbody.files").html ""

    poweroff: () =>
        (new ConfirmModal(lang.maintainpage.warning_poweroff, =>
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).poweroff()
            show_chain_progress(chain, true).fail =>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000))).attach()

    reboot: () =>
        (new ConfirmModal(lang.maintainpage.warning_reboot, =>
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).reboot()
            show_chain_progress(chain, true).fail =>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000)
                )).attach()

    sysinit: () =>
        (new ConfirmModal_more(@vm.lang.btn_sysinit,@vm.lang.warning_sysinit,@sd,@dview,@settings)).attach()

    recover: () =>
        bool = false
        for i in @sd.raids.items
            if i.health == "failed"
                bool = true
            else
                continue
        
        if bool
            (new ConfirmModal_more(@vm.lang.btn_recover,@vm.lang.warning_recover,@sd,@dview,@settings, this)).attach()
        else
            (new MessageModal(lang.maintainpage.warning_raids_safety)).attach()

    apply_fs_name: () =>
        fs_name = ""
        for fs_o in @sd.filesystem.data
            fs_name = fs_o.name
        return fs_name

    scan_system: (v) =>
        fs_name = @apply_fs_name(v)
        if @sd.filesystem.data.length == 0
            chain = new Chain()
            (show_chain_progress chain).done =>
                (new MessageModal lang.volume_warning.no_fs).attach()
        else
            (new ConfirmModal(lang.volume_warning.scan_fs, =>
                @frozen()
                fsrest = (new FileSystemRest(@sd.host))
               
                (fsrest.scan fs_name).done (data) =>
                    if data.status == "success" and data.detail.length > 0
                        (new ConfirmModal_scan(@sd, this, lang.volumepage.th_scan, lang.volumepage.th_scan_warning, data.detail)).attach()
                    else
                        (new MessageModal lang.volumepage.th_scan_safety).attach()
                    @attach()
                .fail =>
                    (new MessageModal lang.volume_warning.scan_fs_fail).attach()
                )).attach()
                
class LoginPage extends Page
    constructor: (@dview) ->
        super "loginpage-", "html/loginpage.html", class: "login"
        @try_login = false
        @_settings = new SettingsManager
        @settings = new (require("settings").Settings)

    define_vm: (vm) =>
        vm.lang = lang.login
        vm.device = ""
        vm.username = "admin"
        vm.passwd = ""
        #vm.passwd = "admin"
        vm.submit = @submit
        vm.keypress = @keypress
        vm.close_alert = @close_alert

    rendered: () =>
        super()
        $.validator.addMethod "isLogined", (value, element) ->
            not (new SettingsManager).isLoginedMachine value
        $(".login-form").validate(
            valid_opt(
                rules:
                    device:
                        required: true
                        isLogined: true
                    username:
                        required: true
                    passwd:
                        required: true
                messages:
                    device:
                        required: "请输入存储IP"
                        isLogined: "您已经登录该设备"
                    username:
                        required: "请输入用户名"
                    passwd:
                        required: "请输入密码"
                errorPlacement: (error, elem) ->
                    error.addClass("help-small no-left-padding").
                        insertAfter(elem.closest(".input-icon"))))

        $("#login-ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.device = item
        )
        #@video()
        @backstretch = $(".login").backstretch([
            "images/login-bg/1.jpg",
            "images/login-bg/2.jpg",
            "images/login-bg/3.jpg",
            "images/login-bg/4.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"

        return
        
    video: () =>
        $(`function() {
            var BV = new $.BigVideo();
            BV.init();
            BV.show('http://vjs.zencdn.net/v/oceans.mp4');
        }`)
        
    attach: () =>
        super()
        return

    detach: () =>
        super()
        @backstretch?.pause?()

    change_device: (device) =>
        @vm.device = device

    close_alert: (e) =>
        $(".alert-error").hide()

    keypress: (e) =>
        @submit() if e.which is 13

    submit: () =>
        port = @settings.port
        return if @try_login
        if $(".login-form").validate().form()
            @try_login = true
            ifaces_request = new IfacesRest("#{@vm.device}:" + port).query()
            ifaces_request.done (data) =>
                if data.status is "success"
                    isLogined = false
                    login_machine = ""
                    settings = new SettingsManager
                    ifaces = (iface.split("/", 1)[0] for iface in data.detail)
                    for iface in ifaces
                        if settings.isLoginedMachine iface
                            isLogined = true
                            login_machine = iface
                    if isLogined
                        (new MessageModal(
                            lang.login.has_logged_error(login_machine))
                        ).attach()
                        @try_login = false
                    else
                        @_login()
                else
                    @_login()
            ifaces_request.fail =>
                @_login()
            
    _login: () =>
        port = @settings.port
        chain = new Chain
        chain.chain =>
            rest = new SessionRest("#{@vm.device}:" + port)
            query = rest.create @vm.username, @vm.passwd
            query.done (data) =>
                if data.status is "success"
                    @dview.token = data.detail.login_id
        chain.chain @dview.init @vm.device
        show_chain_progress(chain, true).done(=>
            version_request = new SystemInfoRest("#{@vm.device}:" + port).query()
            version_request.done (data) =>
                if data.status is "success"
                    _server_version = data.detail["gui version"].substring 0, 3
                    _app_version = @settings.version.substring 0, 3
                    @_init_device()
                    if _server_version == _app_version
                        @dview.attach()
                    else
                        (new MessageModal lang.login.version_invalid_error).attach()
                        @dview.attach()
            version_request.fail =>
                @_init_device()
                @dview.attach()
        ).fail(=>
            @try_login = false
            $('.alert-error', $('.login-form')).show())
            
        
    
    _init_device: =>
        @try_login = false
        @_settings.addUsedMachine @vm.device
        @_settings.addLoginedMachine @vm.device
        @_settings.addSearchedMachine @vm.device
        return
        
##############################################################################

class CentralLoginPage extends Page
    constructor: (@dview) ->
        super "centralloginpage-", "html/centralloginpage.html", class: "login"
        @try_login = false
        @_settings = new SettingsManager
        @settings = new (require("settings").Settings)

    define_vm: (vm) =>
        vm.lang = lang.centrallogin
        vm.device = "192.168.2.58"
        vm.username = "admin"
        vm.passwd = "admin"
        vm.submit = @submit
        vm.keypress = @keypress
        vm.close_alert = @close_alert
        
    rendered: () =>
        super()
        new WOW().init();
        @back_to_top()
        $.validator.addMethod "isLogined", (value, element) ->
            not (new SettingsManager).isLoginedMachine value
        $("form.login-form").validate(
            valid_opt(
                rules:
                    device:
                        required: true
                        isLogined: true
                    username:
                        required: true
                    passwd:
                        required: true
                messages:
                    device:
                        required: "请输入存储IP"
                        isLogined: "您已经登录该设备"
                    username:
                        required: "请输入用户名"
                    passwd:
                        required: "请输入密码"
                errorPlacement: (error, elem) ->
                    error.addClass("help-small no-left-padding").
                        insertAfter(elem.closest(".input-icon"))))
                        
        $("#login-ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.device = item
        )
        
        ###@backstretch = $(".login").backstretch([
            "images/login-bg/1.png",
            "images/login-bg/2.jpg",
            "images/login-bg/3.jpg",
            "images/login-bg/4.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"###
        @placeholder()
        @particles(this)
        
        return
        
    placeholder:() =>
        $(`function(){
            Placeholdem( document.querySelectorAll( '[placeholder]' ) );
            var fadeElems = document.body.querySelectorAll( '.fade' ),
                fadeElemsLength = fadeElems.length,
                i = 0,
                interval = 50;
                function incFade() {
                    if( i < fadeElemsLength ) {
                        fadeElems[ i ].className += ' fade-load';
                        i++;
                        setTimeout( incFade, interval );
                    }
                }
                setTimeout( incFade, interval );
        }`)
        
    submit: () =>
        if !@try_login
            if $("form.login-form").validate().form()
                @try_login = true
                ifaces_request = new IfacesRest("#{@vm.device}:8008").query()
                ifaces_request.done (data) =>
                    if data.status is "success"
                        isLogined = false
                        login_machine = ""
                        settings = new SettingsManager
                        ifaces = (iface.split("/", 1)[0] for iface in data.detail)
                        for iface in ifaces
                            if settings.isLoginedMachine iface
                                isLogined = true
                                login_machine = iface
                        if isLogined
                            (new MessageModal(
                                lang.login.has_logged_error(login_machine))
                            ).attach()
                            @try_login = false
                        else
                            @_login()
                    else
                        @_login()
                ifaces_request.fail =>
                    #@_login()
                    #(new MessageModal lang.login.login_error).attach()
                    $('.alert-error', $('.login-form')).show()
                    @try_login = false
                
    _login: () =>
        chain = new Chain
        chain.chain =>
            rest = new SessionRest("#{@vm.device}:8008")                     #post password and usrname
            query = rest.create "admin", "admin"
            query.done (data) =>
                if data.status is "success"
                    @dview.token = data.detail.login_id                    
        chain.chain @dview.init @vm.device
        show_chain_progress(chain, true).done(=>
            version_request = new SystemInfoRest("#{@vm.device}:8008").query()              #get systeminfo
            version_request.done (data) =>
                if data.status is "success"
                    $("#logout_btn").show()
                    _server_version = data.detail["gui version"].substring 0, 3
                    _settings = new (require("settings").Settings)
                    _app_version = _settings.version.substring 0, 3
                    @_init_device()
                    if _server_version is _app_version
                        @dview.attach()
                        @dview.show_log()
                        #@tips(@dview.get_data())
                    else
                        (new MessageModal lang.login.version_invalid_error).attach()
                        @dview.attach()
            version_request.fail =>
                @_init_device()
                @dview.attach()
        ).fail(=>
            @try_login = false
            $('.alert-error', $('.login-form')).show())
                            
    ###submit: () =>
        chain = new Chain
        chain.chain @dview.init @vm.device
        show_chain_progress(chain, true).done(=>
            @dview.attach()
            
        ).fail(=>
            @dview.attach()) ###  
            
    tips:(sd) =>
        try
            info = []
            datas = {}
            type = {}
            for i in sd.centers.items
                info.push i.Ip
                datas[i.Ip] = 0
                type[i.Ip] = i.Devtype
                
            ((datas[j.ip] = datas[j.ip] + 1 )for j in sd.stores.items.journals when j.ip in info)
            for k in info
                if datas[k] > 0
                    if type[k] is "storage"
                        types = "存储"
                    else
                        types = "服务器"
                    @show_tips(k,datas[k],types)
        catch e
            console.log e
                
    show_tips:(ip,num,type) =>
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
                text: '<a href="#" style="color:#ccc;font-size:14px;">' + type + ip + '有' + num + '条告警信息</a><br>点击可查看.'
            });
            return false;
        }`)
        
    back_to_top:() =>
        $(`function() {
            if ($('#back-to-top').length) {
                var scrollTrigger = 100, // px
                    backToTop = function () {
                        var scrollTop = $(window).scrollTop();
                        if (scrollTop > scrollTrigger) {
                            $('#back-to-top').addClass('show');
                        } else {
                            $('#back-to-top').removeClass('show');
                        }
                    };
                backToTop();
                $(window).on('scroll', function () {
                    backToTop();
                });
                $('#back-to-top').on('click', function (e) {
                    e.preventDefault();
                    $('html,body').animate({
                        scrollTop: 0
                    }, 700);
                });
            }
        }`)
        
    particles: (page) =>
        $(`function() {
            particlesJS("particles-js", {
              "particles": {
                "number": {
                  "value": 70,
                  "density": {
                    "enable": true,
                    "value_area": 800
                  }
                },
                "color": {
                  "value": "#ffffff"
                },
                "shape": {
                  "type": "circle",
                  "stroke": {
                    "width": 0,
                    "color": "#000000"
                  },
                  "polygon": {
                    "nb_sides": 5
                  },
                  "image": {
                    "src": "img/github.svg",
                    "width": 100,
                    "height": 100
                  }
                },
                "opacity": {
                  "value": 0.5,
                  "random": false,
                  "anim": {
                    "enable": false,
                    "speed": 1,
                    "opacity_min": 0.1,
                    "sync": false
                  }
                },
                "size": {
                  "value": 3,
                  "random": true,
                  "anim": {
                    "enable": false,
                    "speed": 40,
                    "size_min": 0.1,
                    "sync": false
                  }
                },
                "line_linked": {
                  "enable": true,
                  "distance": 150,
                  "color": "#ffffff",
                  "opacity": 0.4,
                  "width": 1
                },
                "move": {
                  "enable": true,
                  "speed": 0.5,
                  "direction": "none",
                  "random": false,
                  "straight": false,
                  "out_mode": "out",
                  "bounce": false,
                  "attract": {
                    "enable": false,
                    "rotateX": 600,
                    "rotateY": 1200
                  }
                }
              },
              "interactivity": {
                "detect_on": "canvas",
                "events": {
                  "onhover": {
                    "enable": false,
                    "mode": "grab"
                  },
                  "onclick": {
                    "enable": false,
                    "mode": "push"
                  },
                  "resize": true
                },
                "modes": {
                  "grab": {
                    "distance": 140,
                    "line_linked": {
                      "opacity": 1
                    }
                  },
                  "bubble": {
                    "distance": 400,
                    "size": 30,
                    "duration": 2,
                    "opacity": 8,
                    "speed": 3
                  },
                  "repulse": {
                    "distance": 200,
                    "duration": 0.4
                  },
                  "push": {
                    "particles_nb": 4
                  },
                  "remove": {
                    "particles_nb": 2
                  }
                }
              },
              "retina_detect": true
            });
        }`)
        
    keypress: (e) =>
        @submit() if e.which is 13 and !@try_login
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _init_device: =>
        @try_login = false
        @_settings.addUsedMachine @vm.device
        @_settings.addLoginedMachine @vm.device
        @_settings.addSearchedMachine @vm.device
        return

class CentralServerViewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralserverviewpage-", "html/centralserverviewpage.html"

        @flow_max = 0
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.server_cpu
                @vm.cache_load  = parseInt latest.server_system
                @vm.mem_load = parseInt latest.server_mem
                
                @vm.per_docker = parseInt latest.server_docker
                @vm.per_tmp = parseInt latest.server_tmp
                @vm.per_var = parseInt latest.server_var
                @vm.per_system = parseInt latest.server_system_cap
                @vm.per_weed_cpu = parseInt latest.server_weed_cpu
                @vm.per_weed_mem = parseInt latest.server_weed_mem
                
                @vm.total_read = parseInt latest.server_total_read
                @vm.total_write = parseInt latest.server_total_write

                
                @refresh_num()
                @refresh_mini_chart(latest)
                #try
                #    @bubble parseInt(latest.server_cpu),parseInt(latest.server_system),parseInt(latest.server_mem)
                #catch e
                #    console.log e
                #@spark @sd.stats.items[0].exports.length,@_process()
                #@monitor(latest)
                #@vm.on_monitor = @_ping()
                #@plot_flow_in source.items
                #@plot_flow_out source.items
                #@sparkline_stats(latest.server_system,latest.temp,latest.server_cap)
                #@refresh_pie()
                
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems()
            
        $(@sd.centers).on "updated", (e, source) =>
            num = []
            ((num.push i) for i in source.items when i.Devtype is "export" and i.Status)
            @vm.on_monitor = num.length
            
    define_vm: (vm) =>
        vm.lang = lang.central_server_view
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.colony_num = 0
        vm.machine_num = 0
        vm.warning_num = 0
        vm.process_num = 0
        vm.total_monitor = 0
        vm.on_monitor = 0
        vm.per_docker = 0
        vm.per_tmp = 0
        vm.per_var = 0
        vm.per_system = 0
        vm.per_weed_cpu = 0
        vm.per_weed_mem = 0
        vm.total_read = 0
        vm.total_write = 0 
        
        vm.show_fillgauge = false
        vm.clear_log = @clear_log
        vm.status_server = "normal"
        vm.change_status = @change_status
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered
        vm.fattr_journal_status = fattr.journal_status
        vm.fattr_monitor_status = fattr.monitor_status
        vm.fattr_view_status = fattr.view_status
        vm.switch_to_page = @switch_to_page
        
        vm.journal = @subitems()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered
        vm.detail_cpu = @detail_cpu
        vm.detail_cache = @detail_cache
        vm.detail_mem = @detail_mem
        vm.handle_log = @handle_log
        vm.changeflot = @changeflot
        vm.alarm = @alarm()
        vm.logs = @logs()
        vm.show_detail_modal = @show_detail_modal
        vm.open_capture = @open_capture
        vm.close_capture = @close_capture
        
    rendered: () =>
        super()
        $('.tip-twitter').remove();
        new WOW().init();
        $('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            allowTipHover: false
            fade: true
            slide: false
            followCursor: true
        )
        @vm.show_fillgauge = false
        @vm.journal = @subitems()
        @vm.journal_info = @subitems_info()
        @vm.journal_warning = @subitems_warning()
        @vm.journal_critical = @subitems_critical()
        @vm.logs = @logs()
        #@data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        #@data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        #@data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        #@data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        #@data_table5= $("#timeline_log").dataTable dtable_opt(retrieve: true, bSort: false,scrollX: true)
        
        
        #$('.countup').counterUp({delay: 2,time: 1000})
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        $scroller5 = $("#scroller_timeline")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
        $scroller5.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller5.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
        @timeline()
        @nprocess()
        @datatable_init(this)
        try
            @plot_flow_in @sd.stats.items
            #@plot_flow_out @sd.stats.items
            @vm.alarm = @alarm()
            @refresh_num()
            @bubble @sd.stats.items
            @mini_chart()
            
        catch e
            console.log e
        
        
    
        #@process_stats()
        #@sparkline_stats 50
        #@update_circle()
        #$('.tooltips').tooltip()
        #$("#count1").addClass "animated zoomIn"
        #$("#count2").addClass "animated zoomIn"
        #$("#count3").addClass "animated zoomIn"
        #$("#count4").addClass "animated zoomIn"
        #$('#count1').counterUp({delay: 3,time: 1000})
        #$(".dataTables_filter select").css({ background: "url('images/chosen-sprite.png')"})
        #@calendar()
        #@spark 1,2
        #@flot_cpu @sd.stats.items
        #@flot_mem @sd.stats.items
        #@flot_cache @sd.stats.items
        
    open_capture:() =>
        (new ConfirmModal("确认要开启抓包吗", =>
            @frozen()
            chain = new Chain()
            chain.chain => (new MachineRest(@sd.host)).open_capture
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal "开启成功").attach()
        )).attach()
    
    close_capture:() =>
        (new ConfirmModal("确认要关闭抓包吗", =>
            @frozen()
            chain = new Chain()
            chain.chain => (new MachineRest(@sd.host)).close_capture
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal "关闭成功").attach()
        )).attach()
        
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),1000
    
    show_detail_modal:() =>
        (new CentralShowServerDetailModal(@sd, this)).attach()
        
    subitems: () =>
        try
            arrays = []
            ###for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if i.status
                    i.chinese_status = "已处理"
                else
                    i.chinese_status = "未处理"
                arrays.push i
            arrays.reverse()###
            arrays
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'critical')
        info
        
    logs :() =>
        arrays = [{"date":"2016/09/07","time":"08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07","time":"09:45:37","level":"critical","chinese_message":"阵列 RAID 已损坏"},\
                  {"date":"2016/09/07","time":"10:45:37","level":"critical","chinese_message":"阵列 RAID 已重建"},\
                  {"date":"2016/09/07","time":"12:45:37","level":"warning","chinese_message":"阵列 RAID 已降级"},\
                  {"date":"2016/09/07","time":"12:55:37","level":"info","chinese_message":"虚拟磁盘 VOL 已损坏"},\
                  {"date":"2016/09/07","time":"13:15:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07","time":"19:35:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07","time":"20:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07","time":"23:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07","time":"23:55:37","level":"warning","chinese_message":"阵列 RAID 已创建"}]
        arrays
        
    datatable_init: (page) =>
        $(`function() {
            $('#filter th').each( function () {
                var title = $('#log-table1 thead th').eq( $(this).index() ).text();
                $(this).html( '<input style="border: 1px solid #C2CAD8;width:120px;height:10px;padding:10px;font-family:Microsoft YaHei" type="text" placeholder="搜索'+title+'" />' );
            } );
            
            var table1 = $("#log-table1").DataTable(dtable_opt({
                //retrieve: true,
                //bSort: false,
                //scrollX: true,
                destroy:true,
                bProcessing: true,
                bServerSide: true,
                sAjaxSource: "http://" + page.sd.host + "/api/journals",
                sServerMethod: "POST",
                aoColumnDefs: [
                  {
                    "aTargets": [1],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                      if (full[1] === "info") {
                        return "<span class='label label-success'><i class='icon-volume-up'></i>提醒</span>";
                      } else if (full[1] === "warning") {
                        return "<span class='label label-warning'><i class='icon-warning-sign'></i>警告</span>";
                      } else {
                        return "<span class='label label-important'><i class='icon-remove'></i>错误</span>";
                      }
                    }
                  },{
                    "aTargets": [2],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                      if (full[2]) {
                        return "<span class='label label-success'>已处理</span>";
                      } else {
                        return "<span class='label label-warning'>未处理</span>";
                      }
                    }
                  }
                ],
                fnServerData: function(sSource, aoData, fnCallback){
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      //page.count_day(page,page.sd.pay.items);
                      if(resp.aaData.length !== 0){
                        //$('#log_event').attr('style', 'display:block;');
                      }
                      return fnCallback(resp);
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }/*,
                initComplete: function () {
                    var api = this.api();
                    api.columns().indexes().flatten().each( function ( i ) {
                        var column = api.column( i );
                        var select = $('<select><option value=""></option></select>')
                            .appendTo( $(column.footer()).empty() )
                            .on( 'change', function () {
                                var val = $.fn.dataTable.util.escapeRegex(
                                    $(this).val()
                                );
                                column
                                    .search( val ? '^'+val+'$' : '', true, false )
                                    .draw();
                            } );
                        column.data().unique().sort().each( function ( d, j ) {
                            select.append( '<option value="'+d+'">'+d+'</option>' )
                        });
                    });
                }*/
            }));
            $(".dataTables_filter input").addClass("m-wrap small");
            $(".dataTables_length select").addClass("m-wrap small");
            /*table1.columns().eq( 0 ).each( function ( colIdx ) {
                $( 'input', table1.column( colIdx ).footer() ).on( 'keyup change', function () {
                    table1
                        .column( colIdx )
                        .search( this.value )
                        .draw();
                } );
            } );*/
        }`)
        
    refresh_mini_chart:(items) =>
        try
            docker = items.server_docker
            tmp = items.server_tmp
            vars = items.server_var
            system_cap = items.server_system_cap
            weed_cpu = items.server_weed_cpu
            weed_mem = items.server_weed_mem
            conf_docker = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-docker
                      }, {
                        "x": 2,
                        "value": docker
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_tmp = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-tmp
                      }, {
                        "x": 2,
                        "value": tmp
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_var = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-vars
                      }, {
                        "x": 2,
                        "value": vars
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_system_cap = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-system_cap
                      }, {
                        "x": 2,
                        "value": system_cap
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_weed_cpu = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-weed_cpu
                      }, {
                        "x": 2,
                        "value": weed_cpu
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_weed_mem = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-weed_mem
                      }, {
                        "x": 2,
                        "value": weed_mem
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
            AmCharts.makeChart( "mini_docker_server", conf_docker );
            AmCharts.makeChart( "mini_var_server", conf_var );
            AmCharts.makeChart( "mini_tmp_server", conf_tmp );
            #AmCharts.makeChart( "mini_system_server", conf_system_cap );
            AmCharts.makeChart( "mini_weed_cpu_server", conf_weed_cpu );
            AmCharts.makeChart( "mini_weed_mem_server", conf_weed_mem );
        catch e
            return

    mini_chart:() =>
        defaults = {
                "type": "pie",
                "dataProvider": [ {
                   "x": 1,
                   "value": 100
                }, {
                   "x": 2,
                   "value": 0
                } ],
                "labelField": "x",
                "valueField": "value",
                "labelsEnabled": false,
                "balloonText": "",
                "valueText": undefined,
                "radius": 9,
                "outlineThickness": 1,
                "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                "startDuration": 0
            };
        AmCharts.makeChart( "mini_docker_server", defaults );
        AmCharts.makeChart( "mini_var_server", defaults );
        AmCharts.makeChart( "mini_tmp_server", defaults );
        AmCharts.makeChart( "mini_weed_cpu_server", defaults );
        AmCharts.makeChart( "mini_weed_mem_server", defaults );
        
    timeline:() =>
        $(`function(){
            var $timeline_block = $('.cd-timeline-block');
            //hide timeline blocks which are outside the viewport
            $timeline_block.each(function(){
                if($(this).offset().top > $(window).scrollTop()+$(window).height()*0.75) {
                    $(this).find('.cd-timeline-img, .cd-timeline-content').addClass('is-hidden');
                }
            });
            //on scolling, show/animate timeline blocks when enter the viewport
            $(window).on('scroll', function(){
                $timeline_block.each(function(){
                    if( $(this).offset().top <= $(window).scrollTop()+$(window).height()*0.75 && $(this).find('.cd-timeline-img').hasClass('is-hidden') ) {
                        $(this).find('.cd-timeline-img, .cd-timeline-content').removeClass('is-hidden').addClass('bounce-in');
                    }
                });
            });
        }`);
        
    refresh_num: () =>
        @vm.colony_num = @_colony()
        @vm.machine_num = @_machine()
        @vm.warning_num = @_warning()
        @vm.process_num = @_process()
        
    changeflot:(flotType) =>
        if flotType is "current"
            $('#load_stats_content_current').attr('style', 'display:block');
            $('#load_stats_content_plus').attr('style', 'display:none');
        else
            $('#load_stats_content_current').attr('style', 'display:none');
            $('#load_stats_content_plus').attr('style', 'display:block');
    
    alarm: () =>
        return @sd.warnings.items
        
    handle_log:() =>
        (new CentralHandleLogModal(@sd, this)).attach()
        
    bubble : (items) =>
        $(`function (){
            var config1 = liquidFillGaugeDefaultSettings();
            var config2 = liquidFillGaugeDefaultSettings();
            var config3 = liquidFillGaugeDefaultSettings();
            
            config1.waveAnimateTime = 1000;
            config2.waveAnimateTime = 1000;
            config3.waveAnimateTime = 1000;
            
            config1.textVertPosition = 0.8;
            config2.textVertPosition = 0.8;
            config3.textVertPosition = 0.8;
            
            config1.circleThickness= 0.03;
            config2.circleThickness= 0.03;
            config3.circleThickness= 0.03;
            
            config1.textSize = 0;
            config2.textSize = 0;
            config3.textSize = 0;
            
            config1.textColor = "rgba(0,0,0,0)";
            config2.textColor = "rgba(0,0,0,0)";
            config3.textColor = "rgba(0,0,0,0)";
            
            config1.circleColor = "rgba(87, 199, 212,0.8)";
            config2.circleColor = "rgba(98, 168, 234,0.8)";
            config3.circleColor = "rgba(146, 109, 222,0.8)";
            
            config1.waveColor = "rgba(87, 199, 212,0.5)";
            config2.waveColor = "rgba(98, 168, 234,0.5)";
            config3.waveColor = "rgba(146, 109, 222,0.5)";
            
            config1.circleFillGap = 0;
            config2.circleFillGap = 0;
            config3.circleFillGap = 0;
            
            var gauge1 = loadLiquidFillGauge("fillgauge1", 0, config1);
            var gauge2 = loadLiquidFillGauge("fillgauge2", 0, config2);
            var gauge3 = loadLiquidFillGauge("fillgauge3", 0, config3);
            
            var gauge_interval = setInterval(function () {
                try{
                    var cpu = items[items.length - 1].server_cpu;
                        system = items[items.length - 1].server_system;
                        mem = items[items.length - 1].server_mem;
                    gauge1.update(cpu);
                    gauge2.update(system);
                    gauge3.update(mem);
                }
                catch(e){
                    return;
                }
            }, 3000);
            global_Interval.push(gauge_interval);
        }`);
        ###config.circleThickness = 0.15;
            config.circleColor = "#808015";
            config.textColor = "#fff";
            config.waveTextColor = "#FFF";
            config.waveColor = "#AAAA39";
            config.textVertPosition = 0.8;
            config.waveAnimateTime = 1000;
            config.waveHeight = 0.05;
            config.waveAnimate = true;
            config.waveRise = false;
            config.waveHeightScaling = false;
            config.waveOffset = 0.25;
            config.textSize = 0.75;
            config.waveCount = 3;
            var config1 = config;
            var config2 = config;
            var config3 = config;
            ###
            
    spark: (total,online) =>
        $(`function() {  
            $("#sparkline1").sparkline([online,total-online], {
                type: 'pie',
                width: '110',
                height: '110',
                borderColor: '#',
                sliceColors: ['rgb(227, 91, 90)','rgba(227, 91, 90,0.5)']})
            $("#sparkline2").sparkline([5,6,7,9,9,5,3,2,2,4,6,7], {
                type: 'line',
                width: '200px',
                height: '50px',
                lineColor: '#0000ff'});
            $("#sparkline3").sparkline([5,6,7,9,9,5,3,2,2,4,6,7], {
                type: 'line',
                width: '150px',
                height: '50px',
                lineColor: '#0000ff'});
            $('#sparkline1').bind('sparklineRegionChange', function(ev) {
                var sparkline = ev.sparklines[0],
                    region = sparkline.getCurrentRegionFields(),
                    value = region.percent;
                $('.mouseoverregion').text("使用率:" + value);
            }).bind('mouseleave', function() {
                $('.mouseoverregion').text('');
            });
        }`)
        
    _ping: () =>
        num = []
        ((num.push i) for i in @sd.centers.items when i.Devtype is "export" and i.Status)
        num.length
        
    _colony: () =>
        option = [0]
        ((option.push i.cid) for i in @sd.clouds.items when i.cid not in option and i.devtype is "storage")
        max = Math.max.apply(null,option)
        max
        
    _machine: () =>
        option = []
        ((option.push i.cid) for i in @sd.clouds.items when i.devtype is "export")
        option.length
        
    _warning: () =>
        @sd.journals.items.length
        
    _process: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp.length
            
    update_circle: () =>
        opt1 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(87, 199, 212)",trackColor: 'rgba(87, 199, 212,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(98, 168, 234)",trackColor: 'rgba(98, 168, 234,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(146, 109, 222)",trackColor: 'rgba(146, 109, 222,0.1)',scaleColor: false
        try
            $("#cpu-load").easyPieChart opt1
            $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
            $("#cache-load").easyPieChart opt2
            $("#cache-load").data("easyPieChart").update? @vm.cache_load
            $("#mem-load").easyPieChart opt3
            $("#mem-load").data("easyPieChart").update? @vm.mem_load
        catch e
            return
            
    change_status: (type) =>
        @vm.status_server = type
        
    clear_log:() =>
        if @vm.journal.length is 0
            (new MessageModal @vm.lang.clear_log_error).attach()
            return
        (new ConfirmModal(@vm.lang.clear_log_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new JournalRest(@sd.host)).delete_log())
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.clear_log_success).attach()
        )).attach()
        
    detail_cpu: () =>
        (new CentralServerCpuModal(@sd, this)).attach()
    
    detail_cache: () =>
        return
        #(new CentralServerCacheModal(@sd, this)).attach()
        
    detail_mem: () =>
        (new CentralServerMemModal(@sd, this)).attach()
        
    add_time_to_journal:(items) =>
        journals = []
        change_time = `function funConvertUTCToNormalDateTime(utc)
        {
            var date = new Date(utc);
            var ndt;
            ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
            return ndt;
        }`
        for item in items
            item.date = change_time(item.created_at*1000)
            journals.push item
        
        return journals
        
    calendar: () =>
        $(document).ready(`function() {
            $('#calendar').fullCalendar({
            })
        }`)
        
    sparkline_stats: (rate) =>
        return
        arm =
            chart: 
                type: 'pie'
                margin: [0, 0, 0, 0]
            title: 
                text: ''
                verticalAlign: "bottom"
                style: 
                    color: '#000'
                    fontFamily: 'Microsoft YaHei'
                    fontSize:16
            subtitle: 
                text: ''
            xAxis:
                type: 'category'
                gridLineColor: '#FFF'
                tickColor: '#FFF'
                labels: 
                    enabled: false
                    rotation: -45
                    style: 
                        fontSize: '13px'
                        fontFamily: 'opensans-serif'
            yAxis: 
                gridLineColor: '#FFF'
                min: 0
                max:100
                title: 
                    text: ''
                labels: 
                    enabled: true
            credits: 
                enabled:false
            exporting: 
                enabled: false
            legend: 
                enabled: true
            tooltip:
                pointFormat: '<b>{point.y:.1f}%</b>'
                style: 
                    color:'#fff'
                    fontSize:'12px'
                    opacity:0.8
                borderRadius:0
                borderColor:'#000'
                backgroundColor:'#000'
            plotOptions: 
                pie: 
                    animation:false,
                    shadow: false,
                    dataLabels: 
                        enabled: false
                    showInLegend: true
            series: [{
                type: 'pie'
                name: 'Population'
            }]

        $('#sparkline1').highcharts(Highcharts.merge(arm,
            title: 
                text: ''
            colors: ["rgb(40, 183, 121)", "rgba(40, 183, 121,0.5)"]
            series: [{
                name: '系统空间',
                data: [
                    ['已用',   rate*100],
                    ['剩余',   100 - rate*100]
                ]
            }]
        ))
        
    refresh_pie: () =>
        try
            data = []
            latest = @sd.stats.items[@sd.stats.items.length-1]
            ((data.push {name:i.protype,y:i.cpu}) for i in latest.master.process when i.cpu is 0)
            @process_stats data
        catch e
            console.log e
            
    process_stats: () =>
        ###Highcharts.getOptions().plotOptions.pie.colors = (`function () {
            var colors = [],
                base = Highcharts.getOptions().colors[0],
                i;
            for (i = 0; i < 10; i += 1) {
                // Start out with a darkened base color (negative brighten), and end
                // up with a much brighter color
                colors.push(Highcharts.Color(base).brighten((i - 3) / 7).get());
            }
            return colors;
        }()`)###
        $('#process_stats').highcharts(
            chart: 
                plotBackgroundColor: null
                plotBorderWidth: null
                plotShadow: false
                animation: false
                spacingBottom:50
            title: 
                text: '进程cpu占用率'
                verticalAlign: 'bottom'
            tooltip: 
                pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
            credits: 
                enabled:false
            legend: 
                enabled: false
            exporting: 
                enabled: false
            plotOptions: 
                pie: 
                    allowPointSelect: true
                    cursor: 'pointer'
                    dataLabels: 
                        enabled: false
                        format: '<b>{point.name}</b>: {point.percentage:.1f} %'
                        style: 
                            color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
                        connectorColor: 'silver'
            colors: ["rgba(3, 110, 184,1)","rgba(3, 110, 184,0.8)","rgba(3, 110, 184,0.6)","rgba(3, 110, 184,0.4)","rgba(3, 110, 184,0.2)","rgba(3, 110, 184,0.1)"],
            series: [{
                type: 'pie',
                name: '占用比率',
                data: [
                    ['minio',   45.0],
                    ['python',       26.8],
                    {
                        name: 'Chrome',
                        y: 12.8,
                        sliced: true,
                        selected: true
                    },
                    ['bash',    8.5],
                    ['ssh',     6.2],
                    ['access',   0.7]
                ]
            }])
            
    flot_cpu: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_cpu', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_cpu';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(87, 199, 212)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    flot_cache: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_cache', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_cache';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(98, 168, 234)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: true,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    flot_mem: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flot_mem', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    margin:[0,0,0,0],
                    width:200,
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'server_mem';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random();
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineColor: "#FFF",
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                colors:["#62a8ea","#a58add"],
                plotOptions: {
                    areaspline: {
                        lineColor: "rgb(146, 109, 222)",
                        lineWidth:2,
                        fillColor: "#fff",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    plot_flow_in: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_in_interval_ser = setInterval(function () {
                                try{
                                    var type1 = 'server_net_write';
                                    var type2 = 'server_net_read';
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_in_interval_ser);
                            //series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_out_interval_ser = setInterval(function () {
                                try{
                                    var type1 = 'server_total_write';
                                    var type2 = 'server_total_read';
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_out_interval_ser);
                            //series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        
class CentralStoreViewPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralstoreviewpage-", "html/centralstoreviewpage.html"
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                @vm.cpu_load  = parseInt latest.store_cpu
                @vm.cache_load  = parseInt latest.store_cache
                @vm.mem_load = parseInt latest.store_mem
                @vm.system = parseInt latest.store_system
                @vm.temp = parseInt latest.temp 
                @vm.cap = parseInt latest.store_cap
                @vm.vars = parseInt latest.store_var
                
                @vm.store_cap_remain = latest.store_cap_total - latest.store_cap_remain
                @vm.store_cap_total = parseInt(latest.store_cap_total)
                
                @refresh_pie parseInt(latest.store_cap), parseInt(latest.store_cap_total), parseInt(latest.store_cap_remain)
                @vm.cap_num = (latest.store_cap_total/1024).toFixed(2)
                @refresh_store_num()
                @refresh_probar(latest.volume_overview)
                @refresh_mini_chart(latest)
                
                #@sparkline_stats(@vm.system,@vm.temp,@vm.cap)
                #@get_cap(latest)
                #@vm.on_monitor = @_ping()
                #@refresh_num()
                #@waterbubble(latest.store_system,latest.temp,latest.store_cap)
                #@gauge_system(latest.store_system)
                
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems()
           
        $(@sd.centers).on "updated", (e, source) =>
            num = []
            ((num.push i) for i in source.items when i.Devtype is "storage" and i.Status)
            @vm.on_monitor = num.length
        
        $(@sd.stores).on "updated", (e, source) =>
            @vm.warning_number = source.items.NumOfJours
            @vm.disk_number = source.items.NumOfDisks
            @vm.raid_number = source.items.NumOfRaids
            @vm.volume_number = source.items.NumOfVols
            @vm.filesystem_number = source.items.NumOfFs
            
        $(@sd.centers).on "updated", (e, source) =>
            tmp = []
            for i in source.items
                if i.Devtype is "storage"
                    tmp.push i
            @vm.process_num = tmp.length
            
    define_vm: (vm) =>
        vm.lang = lang.central_store_view
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.system = 0
        vm.temp = 0
        vm.cap = 0
        vm.vars = 0
        vm.cap_load = 30
        vm.cap_load_availed = 70
        vm.status_server = "normal"
        vm.change_status = @change_status
        vm.cap_num = 0
        vm.machine_num = 0
        vm.warning_num = 0
        vm.process_num = 0
        vm.connect_number = 0
        vm.break_number = 0
        vm.filesystem_number = 0
        vm.raid_number = 0
        vm.volume_number = 0
        vm.disk_number = 0
        vm.store_cap_remain = 0
        vm.store_cap_total = 0
        vm.clear_log = @clear_log
        vm.journals = []
        vm.flow_type = "fwrite_mb"
        vm.rendered = @rendered
        vm.fattr_journal_status = fattr.journal_status
        vm.fattr_detail_store = fattr.detail_store
        vm.fattr_view_status = fattr.view_status
        vm.fattr_volume_overview = fattr.volume_overview
        vm.switch_to_page = @switch_to_page 
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load-storeview").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "cache_load", (nval, oval) =>
            $("#cache-load-storeview").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load-storeview").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.journal = @subitems()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.journal_unhandled = @subitems_unhandled()
        
        vm.detail_cpu = @detail_cpu
        vm.detail_cache = @detail_cache
        vm.detail_mem = @detail_mem

        vm.detail_break = @detail_break
        vm.detail_disk = @detail_disk   
        vm.detail_raid = @detail_raid
        vm.detail_volume = @detail_volume
        
        vm.switch_net_write = @switch_net_write
        vm.switch_net_read = @switch_net_read
        vm.switch_vol_write = @switch_vol_write
        vm.switch_vol_read = @switch_vol_read
        vm.net_write = @net_write
        vm.net_read = @net_read
        vm.on_monitor = 0
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.journal_unhandled
                r.checked = vm.all_checked
        vm.handle_log = @handle_log
        vm.alarm = @alarm()
        vm.probar = @probar()
        vm.show_volume_overview = false
        vm.show_detail_modal = @show_detail_modal
        
        
    rendered: () =>
        super()
        $('.tip-twitter').remove();
        new WOW().init();
        #@waves()
        PortletDraggable.init()
        @datatable_init(this)
        @vm.show_volume_overview = false
        $('.tooltips').tooltip()
        @vm.journal = @subitems()
        @vm.journal_info = @subitems_info()
        @vm.journal_warning = @subitems_warning()
        @vm.journal_critical = @subitems_critical()
        @vm.journal_unhandled = @subitems_unhandled()
        ###$('.hastip').tinytip({
            tooltip: "Hello There",
            animation : {
                top : -25
            },
            speed : 100,
            preventClose : true
        });###
        $('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            allowTipHover: false
            fade: true
            slide: false
            followCursor: true
        )
        
        #@data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false)#,scrollX: true)
        #@data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false)#,scrollX: true)
        #@data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false)#,scrollX: true)
        #@data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false)#,scrollX: true)
        #$(".dataTables_filter input[type=search]").css({"background-color":"yellow","font-size":"200%"})
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        $scroller5 = $("#volume_scroller")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        
        $scroller5.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller5.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        #$('.countup').counterUp({delay: 2,time: 1000})
        @column_chart @sd.stats.items
        @plot_pie 0,0,0 
        @refresh_num()
        @refresh_store_num()
        @vm.alarm = @alarm()
        @mini_chart()
        @nprocess()
        try
            @update_circle()
            @plot_flow_in @sd.stats.items
            @plot_flow_out @sd.stats.items
            #@pie_system @sd.stats.items
            #@pie_temp @sd.stats.items
            #@pie_cap @sd.stats.items           
            #@progressbar(this)
        catch e
            console.log e
        #@column_chart([])
        #@flot_system @sd.stats.items
        #@flot_temp @sd.stats.items
        #@flot_cap @sd.stats.items
        #@waterbubble 0,0,0
        #@gauge_system @sd.stats.items
        #@sparkline_stats 0,0,0
        #@webcam() 
        
    
        
    update_circle: () =>
        opt1 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(255, 184, 72)",trackColor: 'rgba(255, 184, 72,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(40, 183, 121)",trackColor: 'rgba(40, 183, 121,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 100, lineWidth: 5, lineCap: "butt", barColor: "rgb(52, 152, 219)",trackColor: 'rgba(52, 152, 219,0.1)',scaleColor: false
        try
            $("#cpu-load-storeview").easyPieChart opt1
            $("#cpu-load-storeview").data("easyPieChart").update? @vm.cpu_load
            $("#cache-load-storeview").easyPieChart opt2
            $("#cache-load-storeview").data("easyPieChart").update? @vm.cache_load
            $("#mem-load-storeview").easyPieChart opt3
            $("#mem-load-storeview").data("easyPieChart").update? @vm.mem_load
        catch e
            return
            
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),1000
    
    refresh_probar:(tmp) =>
        if tmp.length
            @vm.show_volume_overview = true
            @vm.probar = tmp
        else
            @vm.show_volume_overview = false
    
    probar:() =>
        ###
        tmp = [{"name":"volume0","ip":"192.168.2.123","avail":"120GB","used":"0.3","uid":"1"}, \
             {"name":"volume1","ip":"192.168.2.93","avail":"140GB","used":"0.1","uid":"2"}, \
             {"name":"volume0","ip":"192.168.2.83","avail":"3420GB","used":"0.6","uid":"3"}, \
             {"name":"volume2","ip":"192.168.2.183","avail":"520GB","used":"0.2","uid":"4"}, \
             {"name":"volume3","ip":"192.168.2.13","avail":"1220GB","used":"0.9","uid":"5"}, \
             {"name":"volume4","ip":"192.168.2.44","avail":"10GB","used":"0.8","uid":"6"}, \
             {"name":"volume5","ip":"192.168.2.121","avail":"320GB","used":"0.1","uid":"7"}, \
             {"name":"volume6","ip":"192.168.2.133","avail":"7820GB","used":"0.4","uid":"8"}, \
             {"name":"volume7","ip":"192.168.2.13","avail":"920GB","used":"0.8","uid":"9"}]
        tmp###
        []
        
    progressbar:(page) =>
        conf = {
            strokeWidth: 4,
            easing: 'easeInOut',
            duration: 1400,
            color: '#FFEA82',
            trailColor: '#eee',
            trailWidth: 1,
            svgStyle: {width: '100%', height: '100%'},
            from: {color: '#FFEA82'},
            to: {color: '#ED6A5A'},
            step: (state, bar) => 
                bar.path.setAttribute('stroke', state.color);
        }
        probar = @probar()
        for i in probar 
            bar = new ProgressBar.Line("#"+i.uid,conf );
            bar.animate(i.used);
    
    subitems: () =>
        try
            #arrays = subitems @sd.journals.items, Uid:"", Message:"", Chinese_message:"", Level:"", Created_at:"", Updated_at:""
            arrays = []
            ###for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if i.status
                    i.chinese_status = "已处理"
                else
                    i.chinese_status = "未处理"
                arrays.push i###
            arrays
        catch error
            return []
        ###arrays = [{"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"critical","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"info","chinese_message":"阵列 RAID 已创建"},\
                  {"date":"2016/09/07 08:45:37","level":"warning","chinese_message":"阵列 RAID 已创建"}]###
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'info')
        info
             
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems() when i.level is 'critical')
        info
        
    subitems_unhandled: () =>
        info = []
        for i in @subitems() 
            if !i.status
                i.chinese_status = "未处理"
                i.checked = false
                info.push i
        info
    
    waves:() =>
        $(document).ready(`function() {
            window.Waves.attach('.wave', ['waves-button', 'waves-float']);
            window.Waves.init();
        }`)
        
    show_detail_modal:() =>
        ###$("input").click(function() {
          var bd = $('<div class="modal-backdrop"></div>');
          bd.appendTo(document.body);
          setTimeout(function() {
            bd.remove();
          }, 2000);
        });###
        #$('<div class="modal-backdrop"></div>').appendTo(document.body);
        (new CentralShowStorageDetailModal(@sd, this)).attach()
        
    datatable_init: (page) =>
        $(`function() {
            $('#filter th').each( function () {
                var title = $('#log-table1 thead th').eq( $(this).index() ).text();
                $(this).html( '<input style="border: 1px solid #C2CAD8;width:120px;height:10px;padding:10px;font-family:Microsoft YaHei" type="text" placeholder="搜索'+title+'" />' );
            } );
            
            var table1 = $("#log-table1").DataTable(dtable_opt({
                //retrieve: true,
                //bSort: false,
                //scrollX: true,
                destroy:true,
                bProcessing: true,
                bServerSide: true,
                sAjaxSource: "http://" + page.sd.host + "/api/journals",
                sServerMethod: "POST",
                aoColumnDefs: [
                  {
                    "aTargets": [1],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                      if (full[1] === "info") {
                        return "<span class='label label-success'><i class='icon-volume-up'></i>提醒</span>";
                      } else if (full[1] === "warning") {
                        return "<span class='label label-warning'><i class='icon-warning-sign'></i>警告</span>";
                      } else {
                        return "<span class='label label-important'><i class='icon-remove'></i>错误</span>";
                      }
                    }
                  },{
                    "aTargets": [2],
                    "mData": null,
                    "bSortable": false,
                    "bSearchable": false,
                    "mRender": function(data, type, full) {
                      if (full[2]) {
                        return "<span class='label label-success'>已处理</span>";
                      } else {
                        return "<span class='label label-warning'>未处理</span>";
                      }
                    }
                  }
                ],
                fnServerData: function(sSource, aoData, fnCallback){
                  return $.ajax({
                    "type": 'post',
                    "url": sSource,
                    "dataType": "json",
                    "data": aoData,
                    "success": function(resp) {
                      //page.count_day(page,page.sd.pay.items);
                      if(resp.aaData.length !== 0){
                        //$('#log_event').attr('style', 'display:block;');
                      }
                      return fnCallback(resp);
                    },
                    "error": function(e) {
                      return console.log('error');
                    }
                  });
                }/*,
                initComplete: function () {
                    var api = this.api();
                    api.columns().indexes().flatten().each( function ( i ) {
                        var column = api.column( i );
                        var select = $('<select><option value=""></option></select>')
                            .appendTo( $(column.footer()).empty() )
                            .on( 'change', function () {
                                var val = $.fn.dataTable.util.escapeRegex(
                                    $(this).val()
                                );
                                column
                                    .search( val ? '^'+val+'$' : '', true, false )
                                    .draw();
                            } );
                        column.data().unique().sort().each( function ( d, j ) {
                            select.append( '<option value="'+d+'">'+d+'</option>' )
                        });
                    });
                }*/
            }));
            $(".dataTables_filter input").addClass("m-wrap small");
            $(".dataTables_length select").addClass("m-wrap small");
            //$('.dataTables_filter input').attr('placeholder', '搜索');
            /*table1.columns().eq( 0 ).each( function ( colIdx ) {
                $( 'input', table1.column( colIdx ).footer() ).on( 'keyup change', function () {
                    table1
                        .column( colIdx )
                        .search( this.value )
                        .draw();
                } );
            } );*/
        }`)
        
    alarm: () =>
        return @sd.warnings.items
        
    handle_log: () =>
        (new CentralHandleLogModal(@sd, this)).attach()
        
    webcam: () =>
        $(`function() {
              var sayCheese = new SayCheese('#webcam', { audio: false });
              sayCheese.on('start', function() {
                this.takeSnapshot();
              });
            
              sayCheese.on('snapshot', function(snapshot) {
                try{
                    var canvas = document.getElementById('canvas'); 
                    var context = canvas.getContext('2d');
                    context.drawImage(snapshot, 0, 0, 320, 240);
                    console.log(snapshot);
                }
                catch(e){
                    return;
                }
              });
            
              sayCheese.start();
              
              $('#shot').click(function () {
                console.log(sayCheese);
                sayCheese.takeSnapshot();
              });
        }`)
            
    _ping: () =>
        num = []
        ((num.push i) for i in @sd.centers.items when i.Devtype is "storage" and i.Status)
        num.length
        
    refresh_mini_chart:(items) =>
        try
            system = items.store_system
            temp = items.temp
            vars = items.store_var

            conf_system = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-system
                      }, {
                        "x": 2,
                        "value": system
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(60, 192, 150,0.3)", "rgb(5, 206, 142)" ],
                      "startDuration": 0
                    };
                    
            conf_temp = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-temp
                      }, {
                        "x": 2,
                        "value": temp
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(60, 192, 150,0.3)", "rgb(5, 206, 142)" ],
                      "startDuration": 0
                    };
                    
            conf_var = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-vars
                      }, {
                        "x": 2,
                        "value": vars
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(60, 192, 150,0.3)", "rgb(5, 206, 142)" ],
                      "startDuration": 0
                    };
            AmCharts.makeChart( "mini_system_store", conf_system );
            AmCharts.makeChart( "mini_temp_store", conf_temp );
            AmCharts.makeChart( "mini_var_store", conf_var );
        catch e
            return
            
    mini_chart:() =>
        defaults = {
                "type": "pie",
                "dataProvider": [ {
                   "x": 1,
                   "value": 100
                }, {
                   "x": 2,
                   "value": 0
                } ],
                "labelField": "x",
                "valueField": "value",
                "labelsEnabled": false,
                "balloonText": "",
                "valueText": undefined,
                "radius": 9,
                "outlineThickness": 1,
                "colors": [ "rgba(60, 192, 150,0.3)", "rgb(5, 206, 142)" ],
                "startDuration": 0
        }
        AmCharts.makeChart( "mini_system_store", defaults );
        AmCharts.makeChart( "mini_temp_store", defaults );
        AmCharts.makeChart( "mini_var_store", defaults );
         
    gauge_system:(system) =>
        console.log system
        $(`function () {
            var gaugeOptions = {
                chart: {
                    type: 'solidgauge'
                },
                title: {
                    text:"",
                    style:{
                        fontWeight:'bold',
                        fontSize:19,
                        color:'#000'
                    }
                },
                pane: {
                    center: ['50%', '85%'],
                    size: '140%',
                    startAngle: -90,
                    endAngle: 90,
                    background: {
                        backgroundColor: (Highcharts.theme && Highcharts.theme.background2) || '#EEE',
                        innerRadius: '60%',
                        outerRadius: '100%',
                        shape: 'arc'
                    }
                },
                tooltip: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                // the value axis
                yAxis: {
                    stops: [
                        [0.1, '#55BF3B'], // green
                        [0.5, '#DDDF0D'], // yellow
                        [0.9, '#DF5353'] // red
                    ],
                    lineWidth: 0,
                    minorTickInterval: null,
                    tickPixelInterval: 400,
                    tickWidth: 0,
                    title: {
                        y: -70
                    },
                    labels: {
                        y: 16
                    }
                },
                plotOptions: {
                    solidgauge: {
                        dataLabels: {
                            y: 5,
                            borderWidth: 0,
                            useHTML: true
                        }
                    }
                }
            };
            // The speed gauge
            $('#sparkline_bar1').highcharts(Highcharts.merge(gaugeOptions, {
                yAxis: {
                    min: 0,
                    max: 100,
                    title: {
                        text: ''
                    }
                },
                credits: {
                    enabled: false
                },
                series: [{
                    name: 'Speed',
                    data: [80],
                    dataLabels: {
                        format: '<div style="text-align:center"><span style="font-size:25px;color:' +
                        ((Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black') + '">{y}</span><br/>' +
                        '<span style="font-size:12px;color:silver">%</span></div>'
                    },
                    tooltip: {
                        valueSuffix: '%'
                    }
                }]
            }));
            setInterval(function () {
                // Speed
                try{
                    var chart = $('#sparkline_bar1').highcharts(),
                        point,
                        newVal,
                        inc;
                    if (chart) {
                        point = chart.series[0].points[0];
                        //inc = Math.round((Math.random() - 0.5) * 100);
                        //newVal = point.y + inc;
                        //if (newVal < 0 || newVal > 200) {
                        //    newVal = point.y - inc;
                        //}
                        newVal = system[system.length - 1]['store_system']
                        point.update(newVal);
                    }
                }
                catch(e){
                    return;
                }
            }, 2000);
        }`)
        
    waterbubble: (system,temp,cap) =>
        opts1 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(87, 199, 212)',   # // Colors
                colorStop: 'rgb(87, 199, 212)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
                
        opts2 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(98, 168, 234)',   # // Colors
                colorStop: 'rgb(98, 168, 234)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
        opts3 = {
                lines: 12, # // The number of lines to draw
                angle: 0, # // The length of each line
                lineWidth: 0.35, # // The line thickness
                #fontSize: 140,
                pointer: {
                  length: 0.76,
                  strokeWidth: 0.034,
                  color: '#000000'
                },
                limitMax: 'false',   # // If true, the pointer will not go past the end of the gauge
                colorStart: 'rgb(146, 109, 222)',   # // Colors
                colorStop: 'rgb(146, 109, 222)',    # // just experiment with them
                strokeColor: '#E0E0E0',   # // to see which ones work best for you
                generateGradient: true
                };
        target1 = document.getElementById('sparkline_bar1'); # // your canvas element
        target2 = document.getElementById('sparkline_bar2'); # // your canvas element
        target3 = document.getElementById('sparkline_bar3'); # // your canvas element
        gauge1 = new Gauge(target1).setOptions(opts1); # // create sexy gauge!
        gauge2 = new Gauge(target2).setOptions(opts2); # // create sexy gauge!
        gauge3 = new Gauge(target3).setOptions(opts3); # // create sexy gauge!
                
        gauge1.maxValue = 100; # // set max gauge value
        gauge1.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge1.set(system); # // set actual value
        gauge1.setTextField(document.getElementById("gauge-text1"));
        gauge2.setTextField(document.getElementById("gauge-text2"));
        gauge3.setTextField(document.getElementById("gauge-text3"));
        
        gauge2.maxValue = 100; # // set max gauge value
        gauge2.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge2.set(temp); # // set actual value
                
        gauge3.maxValue = 100; # // set max gauge value
        gauge3.animationSpeed = 65; # // set animation speed (32 is default value)
        gauge3.set(cap); # // set actual value
       
    refresh_store_num: () =>
        @vm.raid_number = parseInt @sd.stores.items.NumOfRaids
        @vm.volume_number = parseInt @sd.stores.items.NumOfVols
        @vm.disk_number = parseInt @sd.stores.items.NumOfDisks
        @vm.filesystem_number = parseInt @sd.stores.items.NumOfFs
     
    get_cap: (latest) =>
        datas_total = []
        try
            for i in latest.storages
                if i.info[0].df.length = 2
                    datas_total.push {name:i.ip,y:i.info[0].df[1].total}
        catch e
            console.log e
   
        ###for i in @sd.stores.items.Disk
            if i.MachineId not in machine_total
                machine_total.push i.MachineId
                
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = 0
           
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = data_total[i.MachineId] + i.CapSector/2/1024/1024
            
        for i in machine_total
            datas_total.push {name:i,y:data_total[i]}
            
        for i in datas_total
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip ###
        datas_total
        
    column_chart:(items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#column_chart').highcharts({
                    chart: {
                      type: 'column',
                      options3d: {
                        enabled: true,
                        alpha: 10,
                        beta: 20,
                        depth: 170
                      },
                      events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                datas_total = [];
                                try{
                                    for (var i=0;i< items[items.length - 1].storages.length;i++){
                                        if( items[items.length - 1].storages[i].info[0].df.length == 2){
                                            datas_total.push({name: items[items.length - 1].storages[i].ip,y: items[items.length - 1].storages[i].info[0].df[1].total});
                                        }
                                    };
                                    if (datas_total.length == 0){
                                        datas_total = [{name:"随机数据",y:100},{name:"随机数据",y:200},{name:"随机数据",y:300},{name:"随机数据",y:200},{name:"随机数据",y:100},{name:"随机数据",y:50}]
                                    }
                                    series1.setData(datas_total);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                      }
                    },
                    title: {
                      text: ''
                    },
                    subtitle: {
                      text: ''
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    xAxis: {
                      crosshair: true,
                      tickWidth: 0,
                      labels: {
                        enabled: false
                      }
                    },
                    yAxis: {
                      min: 0,
                      title: {
                        text: 'GB'
                      }
                    },
                    tooltip: {
                      headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
                      pointFormat: '<tr><td style="color:{series.color};padding:0"></td>' + '<td style="padding:0"><b>{point.y:.1f}GB </b></td></tr>',
                      footerFormat: '</table>',
                      shared: true,
                      useHTML: true,
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      column: {
                        animation: false,
                        pointPadding: 0.2,
                        borderWidth: 0,
                        color: 'rgba(60, 192, 150,0.2)',
                        borderColor: 'rgb(60, 192, 150)',
                        borderWidth: 1,
                        pointPadding: 0,
                        events: {
                          legendItemClick: function() {
                            return false;
                          },
                          click: function(event) {}
                        }
                      }
                    },
                    series: [
                      {
                        name: '总容量',
                        data: [{name:"随机数据",y:100},{name:"随机数据",y:200},{name:"随机数据",y:300},{name:"随机数据",y:200},{name:"随机数据",y:100},{name:"随机数据",y:50}]
                      }
                    ]
                });
            });
        }`)
        
    pie_system: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar1').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "store_system"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '系统空间',
                      verticalAlign: "bottom",
                      style: {
                        color: 'rgb(141, 141, 141)',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 13
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(87, 199, 212)", "rgba(87, 199, 212,0.2)"],
                    series: [{
                        name: '系统空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_temp: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar2').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "temp"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '温度',
                      verticalAlign: "bottom",
                      style: {
                        color: 'rgb(141, 141, 141)',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 13
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(98, 168, 234)", "rgba(98, 168, 234,0.2)"],
                    series: [{
                        name: '温度',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_cap: (items) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar3').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        var type = "store_cap"
                                        var y = items[items.length - 1][type];
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '存储空间',
                      verticalAlign: "bottom",
                      style: {
                        color: 'rgb(141, 141, 141)',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 13
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(146, 109, 222)", "rgba(146, 109, 222,0.2)"],
                    series: [{
                        name: '存储空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    refresh_num: () =>
        #@vm.cap_num = @_cap()
        @vm.machine_num = @_machine()
        @vm.warning_num = @_warning()
        @vm.process_num = @_process()
        
    _cap: () =>
        cap = 0
        try
            cap = @sd.stats.items[@sd.stats.items.length-1].store_cap_total/1024
        catch e
            console.log e
        cap.toFixed(2)
        
    _machine: () =>
        option = []
        ((option.push i.cid) for i in @sd.clouds.items when i.devtype is "storage")
        option.length
        
    _warning: () =>
        @sd.journals.items.length
        
    _process: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp.length
        
    change_status: (type) =>
        @vm.status_server = type
        
    clear_log:() =>
        if @vm.journal.length is 0
            (new MessageModal @vm.lang.clear_log_error).attach()
            return
        (new ConfirmModal(@vm.lang.clear_log_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new JournalRest(@sd.host)).delete_log())
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.clear_log_success).attach()
        )).attach()

    detail_break: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            (new CentralStoreBreakModal(@sd, this, data.detail)).attach()
        return
    detail_disk: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            console.log data
            try
                (new CentralStoreDiskModal(@sd, this, data.detail.D)).attach()
            catch error
                console.log error
        return
    detail_raid: () => 
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            console.log data
            try
                (new CentralStoreRaidModal(@sd, this, data.detail.R)).attach()
            catch error
                console.log error
        return
    detail_volume: () =>
        return
        ip = '192.168.2.103'
        @frozen()
        detail = (new JournalRest(@sd.host)).disk_info(ip)
        detail.done (data) =>
            (new CentralStoreVolumeModal(@sd, this, data.detail.V)).attach()
        return
        
    detail_cpu: () =>
        (new CentralServerCpuModal(@sd, this)).attach()
    
    detail_cache: () =>
        return
        (new CentralServerCacheModal(@sd, this)).attach()
        
    detail_mem: () =>
        (new CentralServerMemModal(@sd, this)).attach()
        
    add_time_to_journal:(items) =>
        journals = []
        change_time = `function funConvertUTCToNormalDateTime(utc)
        {
            var date = new Date(utc);
            var ndt;
            ndt = date.getFullYear()+"/"+(date.getMonth()+1)+"/"+date.getDate()+"-"+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds();
            return ndt;
        }`
        for item in items
            item.date = change_time(item.created_at*1000)
            journals.push item
        
        return journals
    
    flot_cap: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar3', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'store_cap';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //labels:{
                    //    enabled:false
                    //},
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(87, 199, 212)",
                        lineWidth:1,
                        fillColor: "rgba(87, 199, 212,0.1)",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    flot_system: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar1', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'store_system';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random()
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //labels:{
                    //    enabled:false
                    //},
                    gridLineWidth:0,
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(98, 168, 234)",
                        lineWidth:1,
                        fillColor: "rgba(98, 168, 234,0.1)",
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(165, 138, 221,0.6)"
                        },
                        fillOpacity:0.3
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    flot_temp: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('sparkline_bar2', {
                chart: {
                    type: 'area',
                    //animation:false,
                    //margin:[0,0,0,0],
                    backgroundColor: 'rgba(0,0,0,0)',
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            setInterval(function () {
                                try{
                                    var type1 = 'temp';
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = Math.random();
                                    series1.addPoint([x, y1+y2], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    labels:{
                        enabled:false
                    },
                    gridLineColor: "#FFF",
                    min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                //colors:["#62a8ea","#a58add"],
                plotOptions: {
                    area: {
                        lineColor: "rgb(146, 109, 222)",
                        lineWidth:1,
                        fillColor: "rgba(146, 109, 222,0.1)",
                        fillOpacity:0.3,
                        threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            fillColor:"rgba(255,120,120)"
                        }
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
        }`);
        
    plot_flow_in: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart;
            chart = new Highcharts.Chart({
                chart: {
                    renderTo: 'flow_stats_in',
                    type: 'areaspline',
                    animation:false,
                    //animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_in_interval = setInterval(function () {
                                try{
                                    var type1 = 'store_net_write';
                                    var type2 = 'store_net_read';
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_in_interval);
                            //series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            /*$('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });*/
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart;
            chart = new Highcharts.Chart({
                chart: {
                    renderTo: 'flow_stats_out',
                    type: 'areaspline',
                    animation:false,
                    //animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_out_interval = setInterval(function () {
                                try{
                                    var type1 = 'store_vol_write';
                                    var type2 = 'store_vol_read';
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_out_interval);
                            //series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            /*$('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });*/
        }`);
    
    refresh_pie: (per, total, remain) =>
        ###cap = 0
        used_cap = 0
        
        chain = new Chain
        chain.chain @sd.update("stores")
        console.log @sd.stores.items
        for i in @sd.stores.items.Disk
            cap = cap + i.CapSector
            
        for i in @sd.stores.items.Raid
            if i.Health is 'normal' 
                used_cap = used_cap + i.Used

        cap = cap/2/1024/1024
        per = used_cap/cap*100
        
        if @sd.stores.items.Disk.length isnt 0
            @plot_pie per, cap.toFixed(0), used_cap.toFixed(0), @sd, this
        else
            @plot_pie 0, 0, 0, @sd, this###
        @plot_pie per, total, remain
            
    plot_pie: (per, total ,remain) =>
        if remain is null
           remain = 0
        used = total - remain
        Highcharts.setOptions(
            lang:
                contextButtonTitle:"图表导出菜单"
                decimalPoint:"."
                downloadJPEG:"下载JPEG图片"
                downloadPDF:"下载PDF文件"
                downloadPNG:"下载PNG文件"
                downloadSVG:"下载SVG文件"
                printChart:"打印图表")
        
        $('#pie_chart').highcharts(
                chart: 
                    type: 'pie'
                    options3d:
                        enabled: true
                        alpha: 45
                        beta: 0
                    #marginBottom:70
                title: 
                    text: ''
                tooltip: 
                    pointFormat: '<b>{point.percentage:.1f}%</b>'
                    style:
                        color:'#fff'
                        fontSize:'15px'
                        opacity:0.8
                    borderColor:'#000'
                    backgroundColor:'#000'
                    borderRadius:0
                credits: 
                    enabled:false
                exporting: 
                    enabled: false
                plotOptions: 
                    pie:
                        states:
                            hover:
                                brightness: 0.08
                        allowPointSelect: true
                        animation:false
                        cursor: 'pointer'
                        depth: 25
                        slicedOffset: 15
                        showInLegend: true
                        dataLabels: 
                            enabled: false
                            format: '{point.percentage:.1f} %'
                            style: 
                                fontSize:'14px'
                        point:
                            events:
                                legendItemClick: () ->return false
                                click: (event) ->
                                    return
                                    (new CentralShowStorageDetailModal(@sd, this)).attach()
                legend: 
                    enabled: true
                    backgroundColor: '#FFFFFF'
                    floating: true
                    align: 'right'
                    layout: 'vertical'
                    verticalAlign: 'top'
                    itemStyle: 
                        color: 'rgb(110,110,110)'
                        fontWeight: '100'
                        fontFamily:"Microsoft YaHei"
                    labelFormatter: () ->
                        if @name is '已用容量'
                            return @name + ':' + used + 'GB'
                        else
                            return @name + ':' + remain + 'GB'
                colors:['rgba(5, 206, 142,0.5)', 'rgba(60, 192, 150,0.3)']
                series: [
                    type: 'pie'
                    name: ''
                    data: [
                        ['已用容量', per]
                        ['剩余容量', 100-per]
                    ]
                ])
                
class CentralMonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralmonitorpage-", "html/centralmonitorpage.html"
        
        $(@sd.centers).on "updated", (e, source) =>
            #@vm.total_machine = @subitems_total()
            @vm.devices_store = @subitems_store()
            @vm.devices_server = @subitems_server()
            #@attach()
            #@tree(@vm.devices_store,@vm.devices_server,this,@sd)
            
        table_update_listener @sd.centers, "#monitors", =>
            @vm.total_machine = @subitems_total() if not @has_frozen
            
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                try
                    latest = source.items[source.items.length-1]
                catch e 
                    return
                
        @vm.show_tree_1 = false
        
    define_vm: (vm) =>
        vm.lang = lang.centralmonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        vm.devices_store = @subitems_store()
        vm.devices_server = @subitems_server()
        vm.total_machine = @subitems_total()
        vm.switch_to_page = @switch_to_page
        vm.test = @test
        vm.manual = @manual
        vm.fattr_machine_status = fattr.machine_status
        vm.fattr_monitor_status = fattr.monitor_status
        vm.server_navs = "192.168.2.149"
        vm.tab_click_store = @tab_click_store
        vm.tab_click_server = @tab_click_server
        vm.show_tree_1 = false
        vm.show_loading = true
        vm.tab_listener = @tab_listener
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for v in vm.total_machine
                v.checked = vm.all_checked
        vm.delete_record = @delete_record
    
    rendered: () =>
        super()
        @vm.total_machine = @subitems_total() 
        PortletDraggable.init()
        @vm.show_loading = true
        $('.tooltips').tooltip()
        $('.tooltip_tree').remove()
        @data_table = $("#monitors").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices_store = @subitems_store()
        @vm.devices_server = @subitems_server()
        
        ###$('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target',
            alignX: 'center',
            alignY: 'top',
            offsetY: 0,
            allowTipHover: false,
            fade: false
        )###
        #@tree(@vm.devices_server,@vm.devices_store,this,@sd)
        #@node()
        #@nprocess()
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.total_machine when r.checked)
        if deleted.length isnt 0   
            (new CentralUnmonitorProModal(@sd, this, deleted)).attach()
        else
            (new MessageModal("请选择解除机器")).attach()
            
    tab_listener:(e) =>
        if e is 'graph'
            ((window.clearInterval(i)) for i in global_tree)
            if global_tree.length
                global_tree.splice(0,global_tree.length)
            @tree(@vm.devices_server,@vm.devices_store,this,@sd)
            
    subitems_total:() =>
        array = []
        for i in (@subitems_store()).concat( @subitems_server() )
            if i.name isnt '(请添加)'
                if i.devtype is "storage"
                    i.chinese_type = "存储"
                else
                    i.chinese_type = "服务器"
                i.checked = false
                array.push i
        array
        
    nprocess:() =>
        NProgress.start()
        #setTimeout (=> NProgress.done();$('.fade').removeClass('out')),1000
        
    node: () =>
        $(`function () {
            updateinfo();
            function updateinfo(){
                var json ={"r":{"name":"flare","children":[{"name":"animate","children":[{"name":"Easing"},{"name":"FunctionSequence"},{"name":"ISchedulable"},{"name":"Parallel"},{"name":"Parallel2"},{"name":"Parallel4"},{"name":"Parallel6"},{"name":"Pause"}]}]},"l":{"name":"flare","children":[{"name":"query","children":[{"name":"AggregateExpression","pos":"l"},{"name":"And","pos":"l"},{"name":"Arithmetic","pos":"l"},{"name":"fasdfasdf","pos":"l"},{"name":"Arithmasdfasetic","pos":"l"},{"name":"dfasdfa","pos":"l"}],"pos":"l"}]}};
                var d3js = function(json){
                        var objRight = json['r'] ? json['r'] : {};
                        var objLeft  = json['l'] ? json['l'] : {};
                        d3jsTree('#body',objRight,objLeft);
                    }
                d3js(json);
            }
            
            // d3js tree
            function d3jsTree(aim,objRight,objLeft){
                // $(aim+' svg').remove();
                var m = [20, 120, 20, 120],
                    w = 1280 - m[1] - m[3],
                    h = 600 - m[0] - m[2],  //靠左
                    i = 0;
            
                var tree = d3.layout.cluster().size([h, w]);
            
                var diagonal = d3.svg.diagonal().projection(function(d) { return [d.y, d.x]; });
            
                var vis = d3.select(aim).append("svg")
                            .attr("width", 1200)
                            .attr("height", h + m[0] + m[2])
                            .append("g")
                            .attr("transform", "translate(" + h + "," + m[0] + ")"); // translate(靠左，靠上)
                
                update(objRight,objLeft);
            
                function init_nodes(left){
                    left.x0 = h / 2;
                    left.y0 = 0;
                    var nodes_dic = [];
                    var left_nodes = tree.nodes(left);
                    return left_nodes;
                }
            
                function update(source,l) {
                    var duration = d3.event && d3.event.altKey ? 5000 : 500;
            
                    // Compute the new tree layout.
                    var nodes = init_nodes(source);
                    var left_nodes = init_nodes(l);
                    // if( l !=)
                    var len = nodes.length;
                    for( var i in left_nodes ){
                        nodes[len++] = left_nodes[i];
                    }
            
                    // Normalize for fixed-depth.
                    nodes.forEach(function(d) {
                        tmp = 1;
                        if( d.pos == 'l' ){ tmp = -1;}
                        d.y = tmp * d.depth * 200;  // 线条长度，也是作于方向
                        // d.x = d.l * 63;
                    });
            
                    // Update the nodes…
                    var node = vis.selectAll("g.node")
                        .data(nodes, function(d) { return d.id || (d.id = ++i); });
            
                    // Enter any new nodes at the parent's previous position.
                    var nodeEnter = node.enter().append("g")
                        .attr("class", "node")
                        .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
                        .on("click", function(d) { alert(d.name); }); // 点击事件
                        // .on("click", function(d) { ajax_get_server(d.name);console.log(d);toggle(d); update(d,l); });
            
                    nodeEnter.append("circle")
                        .attr("r", 1e-6)
                        .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });
            
                    nodeEnter.append("text")
                        .attr("x", function(d) { return d.children || d._children ? -10 : 10; })
                        .attr("dy", ".35em")
                        .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
                        .text(function(d) { return d.name; })
                        .style("fill-opacity", 1e-6);
            
                    // Transition nodes to their new position.
                    var nodeUpdate = node.transition()
                        .duration(duration)
                        .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });
            
                    nodeUpdate.select("circle")
                        .attr("r", 4.5)
                        .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });
            
                    nodeUpdate.select("text").style("fill-opacity", 1);
            
                    // Transition exiting nodes to the parent's new position.
                    var nodeExit = node.exit().transition()
                                        .duration(duration)
                                        .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
                                        .remove();
            
                    nodeExit.select("circle")
                        .attr("r", 1e-6);
            
                    nodeExit.select("text")
                        .style("fill-opacity", 1e-6);
            
                    // Update the links…
                    var link = vis.selectAll("path.link")
                                .data(tree.links(nodes), function(d) { return d.target.id; });
            
                    // Enter any new links at the parent's previous position.
                    link.enter()
                        .insert("svg:path", "g")
                        .attr("class", "link")
                        .attr("d", function(d) {
                            var o = {x: source.x0, y: source.y0};
                            return diagonal({source: o, target: o});
                        })
                        .transition()
                        .duration(duration)
                        .attr("d", diagonal);
            
                    // Transition links to their new position.
                    link.transition()
                        .duration(duration)
                        .attr("d", diagonal);
            
                    // Transition exiting nodes to the parent's new position.
                    link.exit()
                        .transition()
                        .duration(duration)
                        .attr("d", function(d) {
                            var o = {x: source.x, y: source.y};
                            return diagonal({source: o, target: o});
                        })
                        .remove();
            
                    // Stash the old positions for transition.
                    nodes.forEach(function(d) {
                        d.x0 = d.x;
                        d.y0 = d.y;
                    });
                }
            
                // Toggle children.
                function toggle(d) {
                    if (d.children) {
                        d._children = d.children; // 闭合子节点
                        d.children = null;
                    } else {
                        d.children = d._children; // 开启子节点
                        d._children = null;
                    }
                }
            }
        }`)
        
    tree: (server,store,page,sd) =>
        #console.log store
        #console.log server
        $(`function () {
            /*var treeData = [{"name":"总分支","children":[{"name":"192.168.2.123","health":true,"parent":"总分支","chinese_health":"健康","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz1"},
                          {"name":"192.168.2.120","health":false,"parent":"总分支","chinese_health":"掉线","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz2"},
                          {"name":"192.168.2.122","health":true,"parent":"总分支","chinese_health":"健康","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz3"},
                          {"name":"192.168.2.143","health":true,"parent":"总分支","chinese_health":"健康","devtype":"export_backup","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz4","pos":"l"},
                          {"name":"192.168.2.140","health":false,"parent":"总分支","chinese_health":"掉线","devtype":"export_master","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz5","pos":"l"}]}];

            var tree_store = [{"name":"192.168.2.123","health":true,"parent":"总分支","chinese_health":"健康","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz1"},
                          {"name":"192.168.2.120","health":false,"parent":"总分支","chinese_health":"掉线","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz2"},
                          {"name":"192.168.2.122","health":true,"parent":"总分支","chinese_health":"健康","devtype":"storage","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz3"}];
                          
            var tree_server = [{"name":"192.168.2.143","health":true,"parent":"总分支","chinese_health":"健康","devtype":"export_backup","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz4","pos":"l"},
                          {"name":"192.168.2.140","health":false,"parent":"总分支","chinese_health":"掉线","devtype":"export_master","slotnr":"24","uuid":"abcdefghijklmnopqstuvwsyz5","pos":"l"}];
            */
            
            // ************** Generate the tree diagram  *****************
            var margin = {top: 20, right: 120, bottom: 20, left: 400},
                width = 860 - margin.right - margin.left,
                height = 500 - margin.top - margin.bottom;
            
            var i = 0,
                duration = 750,
                root;
            
            var tree = d3.layout.tree()
                .size([height, width]);
            
            var diagonal = d3.svg.diagonal()
                .projection(function(d) { return [d.y, d.x]; });
            
            var svg = d3.select("#body").append("svg")
                .attr("width", width + margin.right + margin.left)
                .attr("height", height + margin.top + margin.bottom)
              .append("g")
                .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
            
            //root = treeData[0];
            //root.x0 = height / 2;
            //root.y0 = 0;
            
            var tooltip = d3.select("body")
                  .append("div")
                  .attr("class","tooltip_tree")
                  .style("opacity",0.0);
                  
            var tree_interval = setInterval(function () {
                try{
                    //console.log(232);
                    var _ref;
                    tree_store = [];
                    tree_server = [];
                    for (var i=0;i< store.length;i++){
                        _ref = store[i];
                            var chinese_health;
                            if (_ref.health){
                               chinese_health = "在线"
                            }
                            else{
                               chinese_health = "掉线"
                            }
                            if (_ref.name == "(请添加)"){
                               _ref.role = "storage";
                               _ref.devtype = "storage";
                            }
                            tree_store.push({"name": _ref.name,
                                             "parent": "总分支",
                                             "health":_ref.health,
                                             "chinese_health":chinese_health,
                                             "devtype":_ref.devtype,
                                             "slotnr": _ref.slotnr,
                                             "role":_ref.role,
                                             "uuid":_ref.uuid});
                    };
                    
                    for (var i=0;i< server.length;i++){
                        _ref = server[i];
                        var chinese_health;
                        if (_ref.health){
                           chinese_health = "在线"
                        }
                        else{
                           chinese_health = "掉线"
                        }
                        if (_ref.name == "(请添加)"){
                           _ref.devtype = "export";
                           _ref.role = "master"
                        }
                        tree_server.push({"name": _ref.name,
                                         "health":_ref.health,
                                         "parent": "总分支",
                                         "chinese_health":chinese_health,
                                         "devtype":_ref.devtype,
                                         "role":_ref.role,
                                         "pos":"l",
                                         "slotnr": _ref.slotnr,
                                         "uuid":_ref.uuid});
                    };
                    var json ={"r":{"name":"总分支","children":tree_store},
                               "l":{"name":"总分支","children":tree_server,"pos":"l"}};
                    var objRight = json['r'] ? json['r'] : {};
                    var objLeft  = json['l'] ? json['l'] : {};
                    //NProgress.done();
                    
                    page.vm.show_loading = false;
                    update(objRight,objLeft);
                }
                catch(e){
                    return;
                }
            }, 3000);
            global_Interval.push(tree_interval);
            global_tree.push(tree_interval);
            function init_nodes(left){
                try{
                    left.x0 = height / 2;
                    left.y0 = 0;
                    var nodes_dic = [];
                    var left_nodes = tree.nodes(left);
                    return left_nodes;
                }catch (e){
                    return;
                }
            }
            
            // d3.select(self.frameElement).style("height", "500px");
            
            function update(source,l) {
            
                // Compute the new tree layout.
              
                var nodes = init_nodes(source);
                var left_nodes = init_nodes(l);
                // if( l !=)
                var len = nodes.length;
                for( var i in left_nodes ){
                    nodes[len++] = left_nodes[i];
                }
        
                // Normalize for fixed-depth.
                nodes.forEach(function(d) {
                    tmp = 1;
                    if( d.pos == 'l' ){ tmp = -1;}
                    d.y = tmp * d.depth * 200;  
                    // d.x = d.l * 63;
                });
            
              // Update the nodes…
              var node = svg.selectAll("g.node")
                  .data(nodes, function(d) { return d.id || (d.id = ++i); });
                  
              //tooltip
              
                  
              /*var remove = d3.select("#body")
                  .html('地址:')
                  .append("div")
                  .attr("class","tooltip_tree")
                  .style("opacity",1.0)
                  .style("left", 1000 + "px")
                  .style("top", 1000 + "px");*/
                  
              // Enter any new nodes at the parent's previous position.
              var nodeEnter = node.enter().append("g")
                  .attr("class", "node")
                  .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
                  .on("click", click)
                  .on("mouseover",function(d){
                        if(d.name == "总分支"){
                            return;    
                        }
                        if (d.name == "(请添加)"){
                            tooltip.html(d.name)
                                .style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px")
                                .style("opacity",1.0);
                        }
                        else{
                            tooltip.html('地址:' + d.name + '</br>' + '状态:' + d.chinese_health)
                                .style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px")
                                .style("opacity",1.0);
                        }
                  })
                  .on("mousemove",function(d){
                        tooltip.style("left", (d3.event.pageX) + "px")
                                .style("top", (d3.event.pageY + 20) + "px");
                  })
                  .on("mouseout",function(d){
                        tooltip.style("opacity",0.0);
                  });
                    
              nodeEnter.append("circle")
                  .attr("r", 1e-6)
                  .style("fill", function(d) { 
                        if( d.health){
                            return d._children ? "lightsteelblue" : "#3cc051"; 
                        }
                        else{
                            return d._children ? "lightsteelblue" : "rgb(214, 70, 53)"; 
                        }
                });
                
              nodeEnter.append("image")
                    .attr("x", function(d) {
                      if(d.pos == "l"){
                        return -70;
                      }else{
                        return 23;
                      }
                    })
                    .attr("y", "-30px") 
                    .attr("width",50)  
                    .attr("height",50)  
                    .style("cursor", "pointer")
                    .attr("xlink:href",function(d) {
                        if(d.name == "总分支"){
                             return;    
                        }
                        if(d.devtype == "storage"){
                            return "images/d3/networking.png";
                        }else if(d.devtype == "export"){
                            return "images/d3/computer-master.png";
                        }else{
                            return "images/d3/computer-backup.png";
                        }
                    })
                    .on("click", function(d) {
                        tooltip.html(d.name)
                            .style("opacity",0.0);
                        if (d.name == "(请添加)" || d.name == "总分支" || d.health == 0){
                            return;
                        }
                        if (d.devtype == "export"){
                            return (new CentralServerDetailPage(sd,page,d, page.switch_to_page,d.uuid)).attach();
                        }
                        else{
                            page.frozen();
                            chain = new Chain();
                            chain.chain((function() {
                              return function() {
                                return (new MachineRest(sd.host)).refresh_detail(d.uuid);
                              };
                            })(page));
                            chain.chain(sd.update("all"));
                            return show_chain_progress(chain).done((function() {
                              return function() {
                                page.attach();
                                return page.detail(d);
                              };
                            })(page));
                        }
                  });
                    
              nodeEnter.append("text")
                  .attr("x", function(d) { 
                           if(d.pos == "l"){
                              return -150;
                            }else{
                              return 83;
                            }
                        })
                  .attr("y", function(d) { 
                           if(d.name == "(请添加)"){
                             return d.children || d._children ? 38 : 38; 
                           }else{
                             return d.children || d._children ? 38 : 0; 
                           } 
                   })
                  .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
                  //.text(function(d) {})
                  .text(function(d) { 
                        if(d.name == "总分支" || d.name == "(请添加)"){
                            return "";
                        }else{
                            return d.name;
                        }
                    })
                  .style("fill-opacity", 1e-6)
                  .on("click", function(d) {
                        tooltip.html(d.name)
                            .style("opacity",0.0);
                        if (d.name == "(请添加)" || d.name == "总分支" || !d.health){
                            return;
                        }
                        if (d.devtype == "export"){
                            return (new CentralServerDetailPage(sd,page,d, page.switch_to_page,d.uuid)).attach();
                        }
                        else{
                            page.frozen();
                            chain = new Chain();
                            chain.chain((function() {
                              return function() {
                                return (new MachineRest(sd.host)).refresh_detail(d.uuid);
                              };
                            })(page));
                            chain.chain(sd.update("all"));
                            return show_chain_progress(chain).done((function() {
                              return function() {
                                page.attach();
                                return page.detail(d);
                              };
                            })(page));
                        }
                  });
                  
              /*
              //add icon
              nodeEnter.append("svg:foreignObject")
                  .attr("width", 50)
                  .attr("height", 50)
                  .attr("y", "-16px")
                  .attr("x", function(d) { return d.children || d._children ? -66 : 23; })
                .append("xhtml:span")
                    .attr("class", function(d){
                        if(d.devtype == "storage"){
                            return "icon_storage icon-laptop";
                        }
                        else{
                            return "icon_export icon-desktop";
                        }
                    });*/
               /*
               //add status span
               nodeEnter.append("svg:foreignObject")
                  .attr("width", 50)
                  .attr("height", 50)
                  .attr("y", "-16px")
                  .attr("x", function(d) { return d.children || d._children ? -126 : 63; })
                .append("xhtml:span")
                    .attr("class", function(d){
                        if(d.health){
                            return "span_success";
                        }
                        else{
                            return "span_warning";
                        }})
                    .text(function(d) {
                        if (d.health){
                            return "在线";
                        }
                        else{
                            return "掉线";
                    }});*/
                    
              // Transition nodes to their new position.
              var nodeUpdate = node.transition()
                  .duration(duration)
                  .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });
            
              nodeUpdate.select("circle")
                  .attr("r", function(d) { 
                        if( d.name == "总分支"){
                            return 5; 
                        }
                        else{
                            return 5; 
                        }
                    })
                  .style("fill", function(d) {
                        if(d.name == "总分支"){
                            return d._children ? "lightsteelblue" : "grey"; 
                        } 
                        if( d.health){
                            return d._children ? "lightsteelblue" : "#3cc051"; 
                        }
                        else{
                            return d._children ? "lightsteelblue" : "rgb(214, 70, 53)"; 
                        }
                });
              nodeUpdate.select("image")
              nodeUpdate.select("text")
                 .text(function(d) { 
                        if(d.name == "总分支" || d.name == "(请添加)"){
                            return "";
                        }else{
                            return d.name;
                        }
                    })
                .style("fill-opacity", 1);
            
              // Transition exiting nodes to the parent's new position.
              var nodeExit = node.exit().transition()
                  .duration(duration)
                  .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
                  .remove();
            
              nodeExit.select("circle")
                  .attr("r", 1e-6);
            
              nodeExit.select("text")
                  .style("fill-opacity", 1e-6);
            
              // Update the links…
              var link = svg.selectAll("path.link")
                  .data(tree.links(nodes), function(d) { return d.target.id; });
            
              // Enter any new links at the parent's previous position.
              link.enter().insert("path", "g")
                  .attr("class", "link")
                  .attr("d", function(d) {
                    var o = {x: source.x0, y: source.y0};
                    return diagonal({source: o, target: o});
                  });
            
              // Transition links to their new position.
              link.transition()
                  .duration(duration)
                  .attr("d", diagonal);
            
              // Transition exiting nodes to the parent's new position.
              link.exit().transition()
                  .duration(duration)
                  .attr("d", function(d) {
                    var o = {x: source.x, y: source.y};
                    return diagonal({source: o, target: o});
                  })
                  .remove();
            
              // Stash the old positions for transition.
              nodes.forEach(function(d) {
                d.x0 = d.x;
                d.y0 = d.y;
              });
            }
            
            // Toggle children on click.
            function click(d) {
              return;
              if (d.children) {
                d._children = d.children;
                d.children = null;
              } else {
                d.children = d._children;
                d._children = null;
              }
              update(objRight,objLeft);
            }
        }`)   
        
    tab_click_store: (e) =>
        #console.log e
        #index = parseInt e.currentTarget.dataset.idx
        device = e.currentTarget.$vmodel.e.$model
        if device.name is "(请添加)" or !device.health
            return
        if e.target.className isnt "icon-close"
            @frozen()
            chain = new Chain()
            chain.chain(=> (new MachineRest(@sd.host)).refresh_detail(device.uuid))
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                @detail device
        else
            @unmonitor device
            
    tab_click_server: (e) =>
        #console.log e
        #index = parseInt e.currentTarget.dataset.idx
        device = e.currentTarget.$vmodel.t.$model
        if e.target.className isnt "icon-close"
            @detail device
        else
            @unmonitor device
            
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    manual: () =>
        (new CentralManualModal @sd,this).attach()
        
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "storage" ,(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    console.log machines
                    (new CentralSearchModal @sd, this, machines, "storage" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()

    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems_store: () =>
        if @_subitems_store().length
            all_devices = @get_devices @_subitems_store()
            return all_devices
        return [{name:"(请添加)",health:true}]
        
    subitems_server: () =>
        if @_subitems_server().length
            all_devices = @get_devices @_subitems_server()
            return all_devices
        return [{name:"(请添加)",health:true}]
        
    _subitems_store: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:"",Role:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp
            
    _subitems_server: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:"",Role:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp
            
    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if !device.health
            return (new MessageModal ("机器已掉线")).attach()
        if device.name is '(请添加)'
            return
        if device.devtype is "storage"
            (new CentralStoreDetailPage @sd,this,device,@switch_to_page,device.uuid).attach()
        else
            (new CentralServerDetailPage @sd,this,device,@switch_to_page,device.uuid).attach()
            
    unmonitor: () =>
        (new CentralUnmonitorModal @sd, this ).attach()
        ###
        if device.name is '(请添加)'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    @attach()
                    (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()###
            
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines     

                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            o.devtype = i.Devtype
            o.role = i.Role
            slot.push o
        slots = @compare(slot)
        return slots

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        try
            regex = /\d{1,3}(\.\d{1,3})$/
            temp = machine.match(regex)[0]
            if temp.length == 4
                gap = '.0'
                result = temp.split('.').join(gap)
            else if temp.length == 3
                gap = '.00'
                result = temp.split('.').join(gap)
            else
                result = temp
            return ip:result
        catch e
            return

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when true
                    normal.push i
                when  false
                    failed.push i
                when 'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        
class CentralStoremonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralstoremonitorpage-", "html/centralstoremonitorpage.html"
        #@host = "192.168.2.193:8080"
        $(@sd.centers).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                
    define_vm: (vm) =>
        vm.lang = lang.centralstoremonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        #vm.test = [{ip:"2.88"},{ip:"2.110"}]
        #vm.devices = [[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}],[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}]]
        vm.devices = @subitems()
        vm.switch_to_page = @switch_to_page
        vm.test = @test
        vm.manual = @manual
        vm.fattr_machine_status = fattr.machine_status
        vm.server_navs = "192.168.2.149"
        #vm.store_navs = @store_navs()
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices = @subitems()
    
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    manual: () =>
        (new CentralManualModal @sd,this,"storage").attach()
        
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "storage" ,(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    console.log machines
                    (new CentralSearchModal @sd, this, machines, "storage" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()

    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems: () =>
        if @_subitems().length
            all_devices = @get_devices @_subitems()
            return all_devices[0]
        return [[{name:"请添加",health:true}]]

    _subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "storage")
            tmp

    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if device.name is '请添加' or !device.health
            return
        (new CentralStoreDetailPage @sd,this,device,@switch_to_page).attach()
          
    unmonitor: (device) =>
        if device.name is '请添加'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
                @frozen()
                chain = new Chain()
                chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    @attach()
                    (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()
            
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines     

                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            slot.push o
        slots = @compare(slot)
        for i in slots
            count += 1
            slotgroup.push i
            if machines.length is count or count%4 is 0
                slotgroups.push slotgroup
                slotgroup = []
        return slotgroups

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        try
            regex = /\d{1,3}(\.\d{1,3})$/
            temp = machine.match(regex)[0]
            if temp.length == 4
                gap = '.0'
                result = temp.split('.').join(gap)
            else if temp.length == 3
                gap = '.00'
                result = temp.split('.').join(gap)
            else
                result = temp
            return ip:result
        catch e
            return

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when true
                    normal.push i
                when  false
                    failed.push i
                when 'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        
        
class CentralServermonitorPage extends Page
    constructor: (@sd, @switch_to_page) ->
        super "centralservermonitorpage-", "html/centralservermonitorpage.html"
        #@host = "192.168.2.193:8080"
        $(@sd.centers).on "updated", (e, source) =>
            @vm.devices = @subitems()
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                
    define_vm: (vm) =>
        vm.lang = lang.centralservermonitor
        vm.search = @search
        vm.detail = @detail
        vm.rendered = @rendered
        vm.unmonitor = @unmonitor
        #vm.test = [{ip:"2.88"},{ip:"2.110"}]
        #vm.devices = [[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}],[{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"},{ip:"请扫描"}]]
        vm.devices = @subitems()
        vm.switch_to_page = @switch_to_page
        vm.test = @test

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        @vm.devices = @subitems()
    test: () =>
        chain = new Chain()
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            console.log data
    
    search: () =>
        outline = []
        chain = new Chain()
        bcst = new BCST
        chain.chain bcst.broadcast
        show_chain_progress(chain).done =>
            machines = bcst.getMachines().reverse()
            @_search(machines).sort(@_compare('num'))
            if machines
                if @sd.centers.items != null
                    online = [i.Ip for i in @sd.centers.items]
                    for i in machines
                        if i.ifaces[0] not in online[0]
                            outline.push i
                    if outline.length > 0
                        console.log this
                        (new CentralSearchModal @sd, this, outline, "export",(data)=>
                            @frozen()
                        ).attach()
                    else
                        (new MessageModal (lang.centralview.detect_no_new_machine_info)).attach()
                else
                    (new CentralSearchModal @sd, this, machines, "export" ,(data)=>
                        @frozen()
                    ).attach()
            else
                (new MessageModal (lang.centralview.detect_no_machines_info)).attach()
                
    _search: (machines) =>
        for i in machines
            i.num = Number(i.ifaces[0].split('.')[3])
        return  machines
    
    subitems: () =>
        if @_subitems().length
            all_devices = @get_devices @_subitems()
            return all_devices
        return [[{name:"请添加",health:true}]]
        
    _subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:""
            ((tmp.push i) for i in items when i.Devtype is "export")
            tmp

    get_history_devices: () =>
        tlist = (new MachineRest(@sd.host))
        (tlist.query()).done (data) =>
            if data.detail != null
                machines = @translate data.detail
                all_devices = @get_devices machines
                @vm.devices = all_devices            

    translate: (detail) =>  
        machines = []
        ((machines.push i.Ip) for i in detail when i.Ip not in machines)
        machines

    detail: (device) =>
        if device.name is '请添加' or !device.health
            return
        query = (new MachineRest(@sd.host))
        machine_detail = query.machine device.uuid
        machine_detail.done (data) =>
            console.log data
            if data.status is 'success'
                (new CentralServerDetailPage @sd,this,device,@switch_to_page, data.detail).attach()
            else
                (new MessageModal @vm.lang.detail_error).attach()
        
    unmonitor: (device) =>
        if device.name is '请添加'
            return
        (new ConfirmModal(@vm.lang.unmonitor_tips, =>
            @frozen()
            chain = new Chain()
            chain.chain(=> (new MachineRest(@sd.host)).unmonitor(device.uuid))
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
                (new MessageModal @vm.lang.unmonitor_success).attach()
        )).attach()
        
    _filter_machine: (bcst) =>
        machines = bcst.getDetachMachines()
        shown_machines = @_get_shown_machies()
        temp_machines = []
        isLoged = false
        temp = []
        for machine in machines
            for addr in machine
                if addr in shown_machines
                    isLoged = true
                    break
            if not isLoged
                temp_machines.push machine
            isLoged = false
        machines = []
        for machine in temp_machines
            is_add = false
            if machines.length is 0
                machines.push machine
                continue
            for temp in machines
                if temp[0] in machine
                    is_add = true
                    break
            machines.push machine if not is_add        
        temp_machines = []
        for machine in machines
            for addr in machine
                if bcst.isContained addr
                    temp_machines.push addr
                    break
        temp_machines        
        
    _get_shown_machies: =>
        machines = []
        regex = /^\d{1,3}(\.\d{1,3}){3}$/
        settings = new SettingsManager
        if settings.getSearchedMachines() and settings.getSearchedMachines().length != 0
            for machine in settings.getSearchedMachines()
                machines.push machine if regex.test machine
        machines        
        
                
    get_devices: (machines) =>
        slotgroups = []
        slotgroup = []
        slot = []
        count = 0
        on_monitor = []
        for i in machines.sort(@compare('Ip'))
            o = @_get_devices i.Ip
            o.num = Number(i.Ip.split('.')[3])
            o.uuid = i.Uuid
            o.name = i.Ip
            o.slotnr = i.Slotnr
            o.created = i.Created
            o.health = i.Status
            slot.push o
        slots = @compare(slot)
        for i in slots
            count += 1
            slotgroup.push i
            if machines.length is count or count%4 is 0
                slotgroups.push slotgroup
                slotgroup = []
        return slotgroups

    _get_devices: (machine) =>
        #regex = /(\d{1,3})$/
        try
            regex = /\d{1,3}(\.\d{1,3})$/
            temp = machine.match(regex)[0]
            if temp.length == 4
                gap = '.0'
                result = temp.split('.').join(gap)
            else if temp.length == 3
                gap = '.00'
                result = temp.split('.').join(gap)
            else
                result = temp
            return ip:result
        catch e
            return

    compare: (machines) =>
        failed = []
        degraded = []
        normal = []
        for i in machines
            switch i.health
                when  true
                    normal.push i
                when  false
                    failed.push i
                when  'degraded'
                    degraded.push i
        failed = failed.sort(@_compare('ip'))
        degraded = degraded.sort(@_compare('ip'))
        normal = normal.sort(@_compare('num'))
        return failed.concat(degraded).concat(normal)

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0

    test_1: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]
        


class CentralStoreDetailPage extends Page
    constructor: (@sd, @page, @device, @switch_to_page, @message) ->
        super "centralstoredetailpage-", "html/centralstoredetailpage.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length-1]
                for i in latest.storages
                    if i.ip is @device.name
                        @vm.cpu_load = parseInt i.info[0].cpu
                        @vm.mem_load = parseInt i.info[0].mem
                        @vm.system = parseInt i.info[0].df[0].used_per
                        @vm.temp = parseInt i.info[0].temp
                        
                        if i.info[0].cache_total is 0
                            @vm.cache_load = 0
                        else
                            @vm.cache_load = parseInt(i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total)
                            
                        @refresh_df(i.info[0])
                        
                        @refresh_mini_chart(i.info[0])
                        
                        #system = parseInt i.info[i.info.length - 1].df[0].used_per
                        #cap = parseInt i.info[i.info.length - 1].df[1].used_per
                        #temp = parseInt i.info[i.info.length - 1].temp
                        #@sparkline_stats system,temp,cap
                        #@refresh_flow()
                        
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems_log()
            
        $(@sd.machinedetails).on "updated", (e, source) =>
            if @has_rendered
                try 
                    for i in source.items
                        if i.uuid is @device.uuid
                            array_slot = []
                            array_journal = []
                            if i.disks.length > 0
                                array_slot = i.disks
                            details = @query_list array_slot
                            slot = @get_slots details
                            array_journal = i.journals
                            
                            @vm.slots = slot
                            @vm.raids = i.raids
                            @vm.volumes = i.volumes
                            
                    for t in array_journal
                        t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                        if t.status
                            t.chinese_status = "handled"
                        else
                            t.chinese_status = "unhandled"
                            
                    for j in array_slot
                        if j.raid is ""
                            j.raid = "无"
                    @vm.journal = array_journal.reverse()
                    @vm.disks = array_slot
                    
                catch e
                    console.log e
            
    define_vm: (vm) =>
        vm.lang = lang.centraldisk
        vm.slots = @slots()
        vm.flow_type = "fwrite_mb"
        vm.disks = @disks()
        vm.raids = @raids()
        vm.volumes = @volumes()
        vm.filesystems = @filesystems()
        #vm.initiators = @initiators()
        #vm._smarts = @_smarts()
        #vm.raids = @_subitems()
        #vm.smarts = @smarts()
        #vm.smget = @smget
        #vm.smart = @smarts()[0].smartinfo
        vm.fattr_health = fattr.health
        vm.fattr_role = fattr.role
        vm.fattr_cap = fattr.cap
        vm.fattr_caps = fattr.caps
        vm.fattr_disk_status = fattr.disk_status
        vm.fattr_view_status_fixed = fattr.view_status_fixed
        vm.disk_list = @disk_list
        vm.need_format = false
        vm.switch_to_page = @switch_to_page
        vm.navs = [{title: lang.centralsidebar.overview, icon: "icon-dashboard", id: "overview"},
                   {title: lang.centralsidebar.server, icon: "icon-wrench",   id: "server"}]
        newid = random_id 'menu-'
        
        vm.navss = [{title: lang.adminview.menu_new, icon: "icon-home", menuid: "#{newid}"}]
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.mem_load = 0
        vm.system_load = 0
        vm.cap_load = 0
        vm.var_load = 0
        
        vm.system = 0
        vm.temp = 0
        vm.cap = 0
        
        ###vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "cache_load", (nval, oval) =>
            $("#cache-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return###
        vm.tabletitle = @device.name
        
        vm.fattr_journal_status = fattr.journal_status
        vm.journal = @subitems_log()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered

    rendered: () =>
        super()
        new WOW().init();
        PortletDraggable.init()
        #$("[data-toggle='tooltip']").tooltip()
        $('.tooltips').tooltip()
        $ ->
        $("#myTab li:eq(0) a").tab "show"
        $("#smartTab li:eq(0) a").tab "show"
        
        opt1 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(255, 184, 72)",trackColor: 'rgba(255, 184, 72,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(40, 183, 121)",trackColor: 'rgba(40, 183, 121,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 115, lineWidth: 5, lineCap: "butt", barColor: "rgb(52, 152, 219)",trackColor: 'rgba(52, 152, 219,0.1)',scaleColor: false
        #@data_table = $("#table2").dataTable dtable_opt(retrieve: true)
        #@data_table = $("#table3").dataTable dtable_opt(retrieve: true)
        #@data_table = $("#table4").dataTable dtable_opt(retrieve: true)
        #@data_table = $("#table5").dataTable dtable_opt(retrieve: true)
        
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        ###$("#cpu-load").easyPieChart opt1
        $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
        $("#cache-load").easyPieChart opt2
        $("#cache-load").data("easyPieChart").update? @vm.cache_load
        $("#mem-load").easyPieChart opt3
        $("#mem-load").data("easyPieChart").update? @vm.mem_load###
        
            
        #@refresh_flow()
        #@sparkline_stats 50,10,90
        try
            @plot_flow_in @sd.stats.items,@device.name
            @plot_flow_out @sd.stats.items,@device.name
            @mini_chart()
            ###@pie_system @sd.stats.items,@device.name
            @pie_temp @sd.stats.items,@device.name
            @pie_cap @sd.stats.items,@device.name###
        catch e
            console.log e
            
    refresh_df:(items) =>
        dist = {'var':0,'system':0,'weed_cpu':0,'weed_mem':0}
        total_used = 0
        for i in items.df
            dist[i.name] = i.used_per
        
        if items.fs.length
            for h in items.fs
                total_used = total_used + h.used_per
            @vm.cap_load = parseInt(total_used/items.fs.length)
        else
            @vm.cap_load = 0

        @vm.var_load = parseInt dist.var
        @vm.system_load = parseInt dist.system
        
    refresh_mini_chart:(items) =>
        try
            dist = {'cpu':0,'mem':0,'cache':0,'system':0,'temp':0,'cap':0,'var':0};
            dist['cpu'] = items.cpu;
            dist['mem'] = items.mem;
            dist['cache'] = items.cache_used;
            for i in items.df
                dist[i.name] = i.used_per;

            conf_cpu = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.cpu
                      }, {
                        "x": 2,
                        "value": dist.cpu
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    }
                    
            conf_mem = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.mem
                      }, {
                        "x": 2,
                        "value": dist.mem
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_cache = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.cache
                      }, {
                        "x": 2,
                        "value": dist.cache
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_system = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.system
                      }, {
                        "x": 2,
                        "value": dist.system
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_var = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.var
                      }, {
                        "x": 2,
                        "value": dist.var
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_cap = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-@vm.cap_load
                      }, {
                        "x": 2,
                        "value": @vm.cap_load
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
            AmCharts.makeChart( "mini_cpu_stodetail", conf_cpu );
            AmCharts.makeChart( "mini_mem_stodetail", conf_mem );
            AmCharts.makeChart( "mini_cache_stodetail", conf_cache );
            AmCharts.makeChart( "mini_system_stodetail", conf_system );
            AmCharts.makeChart( "mini_var_stodetail", conf_var );
            AmCharts.makeChart( "mini_cap_stodetail", conf_cap );
        catch e
            return

    mini_chart:() =>
        defaults = {
                "type": "pie",
                "dataProvider": [ {
                   "x": 1,
                   "value": 100
                }, {
                   "x": 2,
                   "value": 0
                } ],
                "labelField": "x",
                "valueField": "value",
                "labelsEnabled": false,
                "balloonText": "",
                "valueText": undefined,
                "radius": 9,
                "outlineThickness": 1,
                "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                "startDuration": 0
            };
        AmCharts.makeChart( "mini_cpu_stodetail", defaults );
        AmCharts.makeChart( "mini_mem_stodetail", defaults );
        AmCharts.makeChart( "mini_cache_stodetail", defaults );
        AmCharts.makeChart( "mini_system_stodetail", defaults );
        AmCharts.makeChart( "mini_var_stodetail", defaults );
        AmCharts.makeChart( "mini_cap_stodetail", defaults );
        
    subitems_log: () =>
        try
            arrays = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                   arrays = i.journals
            for t in arrays
                t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if t.status
                    t.chinese_status = "handled"
                else
                    t.chinese_status = "unhandled"
            arrays.reverse()
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'critical')
        info
        
    pie_system: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar1').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                y = items[items.length - 1].storages[i].info[0].df[0].used_per;
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '系统空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(87, 199, 212)", "rgba(87, 199, 212,0.2)"],
                    series: [{
                        name: '系统空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_temp: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar2').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                y = items[items.length - 1].storages[i].info[0].temp;
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '温度',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(98, 168, 234)", "rgba(98, 168, 234,0.2)"],
                    series: [{
                        name: '温度',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    pie_cap: (items,name) =>
        $(`function () {
            $(document).ready(function () {
                Highcharts.setOptions({
                    global: {
                        useUTC: false
                    }
                });
                $('#sparkline_bar3').highcharts({
                    chart: {
                      type: 'pie',
                      margin: [0, 0, 25, 0],
                      events: {
                            load: function () {
                                var series1 = this.series[0];
                                setInterval(function () {
                                    try{
                                        for (var i=0;i< items[items.length - 1].storages.length;i++){
                                            if( items[items.length - 1].storages[i].ip == name){
                                                if( items[items.length - 1].storages[i].info[0].df.length == 2){
                                                    y = items[items.length - 1].storages[i].info[0].df[1].used_per;
                                                }
                                                else{
                                                    y = 0;
                                                }
                                            }
                                        };
                                        series1.setData([['已用',y], ['剩余',100 - y]]);
                                    }
                                    catch(e){
                                        return;
                                    }
                                }, 3000);
                            }
                        }
                    },
                    title: {
                      text: '存储空间',
                      verticalAlign: "bottom",
                      style: {
                        color: '#000',
                        fontFamily: 'Microsoft YaHei',
                        fontSize: 16
                      }
                    },
                    subtitle: {
                      text: ''
                    },
                    xAxis: {
                      type: 'category',
                      gridLineColor: '#FFF',
                      tickColor: '#FFF',
                      labels: {
                        enabled: false,
                        rotation: -45,
                        style: {
                          fontSize: '13px',
                          fontFamily: 'opensans-serif'
                        }
                      }
                    },
                    yAxis: {
                      gridLineColor: '#FFF',
                      min: 0,
                      max: 100,
                      title: {
                        text: ''
                      },
                      labels: {
                        enabled: true
                      }
                    },
                    credits: {
                      enabled: false
                    },
                    exporting: {
                      enabled: false
                    },
                    legend: {
                      enabled: true,
                      backgroundColor: '#FFFFFF',
                      floating: true,
                      align: 'right',
                      layout: 'vertical',
                      verticalAlign: 'top',
                      itemStyle: {
                        color: 'rgb(110,110,110)',
                        fontWeight: '100',
                        fontFamily: "Microsoft YaHei"
                      }
                    },
                    tooltip: {
                      pointFormat: '<b>{point.y:.1f}%</b>',
                      style: {
                        color: '#fff',
                        fontSize: '12px',
                        opacity: 0.8
                      },
                      borderRadius: 0,
                      borderColor: '#000',
                      backgroundColor: '#000'
                    },
                    plotOptions: {
                      pie: {
                        animation: false,
                        shadow: false,
                        borderColor: "rgba(0,0,0,0)",
                        dataLabels: {
                          enabled: false
                        }
                      }
                    },
                    colors: ["rgb(146, 109, 222)", "rgba(146, 109, 222,0.2)"],
                    series: [{
                        name: '存储空间',
                        data: [
                            ['已用',   0],
                            ['剩余',   100]
                        ]
                    }]
                });
            });
        }`);
        
    subitems: () =>
        items = subitems @_temporary(), Location:"", host:"native", \
        health:"normal", raid:"", role:"unused", cap_sector:5860000000, \
        sn: "WD-WCC2E4EYFU91", vendor: "WDC"
        return items
    
    refresh_flow: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].storages
                if i.ip is @device.name
                    #console.log i.info
                    @plot_flow_in i.info
                    @plot_flow_out i.info
        catch e
            console.log e
            
    refresh: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].storages
                if i.ip is @device.name
                    @vm.cpu_load = i.info[i.info.length - 1].cpu
                    @vm.mem_load = i.info[i.info.length - 1].mem
                    @vm.cache_load = i.info[i.info.length - 1].cache_used/i.info[i.info.length - 1].cache_total
                    system = i.info[i.info.length - 1].df[0].used_per
                    cap = i.info[i.info.length - 1].df[1].used_per
                    temp = i.info[i.info.length - 1].temp
                    @sparkline_stats system,temp,cap
        catch e
            console.log e
            
    plot_flow_in: (yaxis, name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_in_interval_detail = setInterval(function () {
                                try{
                                    var type1 = 'write_mb';
                                    var type2 = 'read_mb';
                                    var x = (new Date()).getTime(); // current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].storages.length;i++){
                                        if( yaxis[yaxis.length - 1].storages[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].storages[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].storages[i].info[0][type2];
                                        }
                                    };
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_in_interval_detail);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        

    plot_flow_out: (yaxis,name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_out_interval_detail = setInterval(function () {
                                try{
                                    var type1 = 'write_vol';
                                    var type2 = 'read_vol';
                                    var x = (new Date()).getTime(); // current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].storages.length;i++){
                                        if( yaxis[yaxis.length - 1].storages[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].storages[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].storages[i].info[0][type2];
                                        }
                                    };
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_out_interval_detail);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        
    disks:() =>
        try
            tmp = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    tmp = i.disks
            for j in tmp
                if j.raid is ''
                    j.raid = '无'
            return tmp
        catch e
            console.log e
    raids:() =>
        try
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.raids
        catch e
            console.log e
    volumes:() =>
        try 
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.volumes
        catch e
            console.log e
        
    filesystems:() =>
        try 
            for i in @sd.machinedetails.items
                if i.uuid is @message
                    return i.filesystems
        catch e
            console.log e
        
    initiators:() =>
        try
            for i in @message.initiators
                i.iface = (portal for portal in i.portals).join ","
                i.map = (volume for volume in i.volumes).join ","
                if i.map is ''
                    i.map = '无'
            return @message.initiators
        catch e
            console.log e
            
    smget: (e) =>
        @vm.smart = e.smartinfo

    smarts: () =>
        try
            smart = ['CurrentPendingSector','LoadCycleCount','OfflineUncorrectable', \
            'PowerCycleCount', 'PowerOffRetractCount', 'PowerOnHours', \
            'RawReadErrorRate', 'ReallocatedSectorCt', 'SeekErrorRate', \
            'SpinRetryCount', 'SpinUpTime', 'StartStopCount', 'UDMACRCErrorCount']
    
            items = subitems @sd.stores.items, Location: "", CurrentPendingSector:"", \
            LoadCycleCount:"", OfflineUncorrectable:"", PowerCycleCount:"", \
            PowerOffRetractCount:"", PowerOnHours: "", RawReadErrorRate: "", \
            ReallocatedSectorCt: "", SeekErrorRate: "", SpinRetryCount: "", \
            SpinUpTime: "", StartStopCount: "", UDMACRCErrorCount: ""
    
            temp = {}
            tem = []
            temps = []
            for i in items
                $.each i, (key, val) ->
                    switch key
                        when 'Location'
                            temp.location = val
                            temp.num = Number(val.split('.')[2])
                        else 
                            tem.push 'name':key,'val':val
                temp.smartinfo = tem
                temps.push temp
                tem = []
                temp = {}
                
            temps.sort(@_compare('num'))
            temps
        
        catch error
            console.log error
            return []

    slots: () =>
        try
            temp = []
            for i in @sd.machinedetails.items
                if i.uuid is @device.uuid
                    if i.disks.length is 0
                        $('.alert-error', $('#accordion2')).show();
                        #(new MessageModal(lang.centraldisk.collect_error)).attach()
                        return
                    else
                        temp = i.disks
                        
            details = @query_list temp
            slot = @get_slots details
            slot
        catch error
            console.log error
        
    _temporary: () =>
        query_disks = (new MachineRest(@sd.host))
        machine_detail = query_disks.machine @device.uuid
        machine_detail.done (data) =>
            if data.detail == null
                @vm.slots = @test()
            else
                details = @query_list data.detail
                slots = @get_slots details
                @vm.slots = slots
            
    query_list: (details) =>
        #console.log details
        query = []
        o = {}
        try
            for i in details
                o = location:i.location, uuid:i.id, role:i.role,\
                raid:i.raid, health:i.health, cap_sector:i.cap_sector
                query.push o
            items = subitems query, location:"", host:"native", \
            health:"", raid:"", role:"", cap_sector:5860000000, \
            sn: "WD-WCC2E4EYFU91", vendor: "WDC", type: "enterprise", model: "WD5000AAKX-60U6AA0" 

            return items
        catch error
            return []

    _subitems: () =>
        chain = new Chain()
         
        query_disks = (new MachineRest(@sd.host))
        #console.log query_disks
        machine_detail = query_disks.machine @device.uuid
        machine_detail.done (data) =>
            if data.detail is not null
                machines =  @get_slots_b data.detail
                return machines

    get_slots_b: (details) =>
        slotgroups = []
        slotgroup = []
        count = 0

        for i in details
            count += 1
            o = @_get_slots_b i.Location
            o.raid = "normal"
            o.raidcolor = "color0"
            o.role = "unused"
            slotgroup.push o
            if details.length is count or count%4 is 0 
                slotgroups.push slotgroup
                slotgroup = []
        
        return slotgroups

    _get_slots_b: (machine) =>
        regex = /\.(\d{1,2})$/
        return slot:machine.match(regex)[1]
        
            
    get_slots: (temp) =>
        slotgroups = []
        slotgroup = []
        dsus = [{location:"1.1",support_disk_nr:@device.slotnr}]
        dsu_disk_num = 0
        raid_color_map = @_get_raid_color_map(temp)
        for dsu in dsus
            for i in [1..dsu.support_disk_nr]
                o = @_has_disk(i, dsu, dsu_disk_num, temp)
                o.raidcolor = raid_color_map[o.raid]
                o.info = @_get_disk_info(i, dsu, temp)
                slotgroup.push o
                if i%4 is 0
                    slotgroups.push slotgroup
                    slotgroup = []
            dsu_disk_num = dsu_disk_num + dsu.support_disk_nr

        #console.log slotgroups
        return slotgroups

    get_raids: () =>
        raids = []
        raid_color_map = @_get_raid_color_map()
        for key, value of raid_color_map
            o = name:key, color:value
            raids.push o
        return raids

    disk_list: (disks) =>
       
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)

    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', \
        'kicked':'损坏', 'global_spare':'全局热备盘', 'data&spare':'数据热备盘'}
        type = {'enterprise': '企业盘', 'monitor': '监控盘', 'sas': 'SAS盘'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length == 0
                        val = '无'
                    status += '阵列: ' + val + '<br/>'
                when 'vendor'
                    status += '品牌: ' + val + '<br/>'
                when 'sn'
                    status += '序列号: ' + val + '<br/>'
                when 'model'
                    status += '型号: ' + val + '<br/>'
                when 'type'
                    name = '未知'
                    mod = obj.model.match(/(\S*)-/)[1];
                    $.each disks_type, (j, k) ->
                        if mod in k
                            name = type[j]
                    status += '类型: ' + name + '<br/>'
                    
        status
        
    _get_disk_info: (slotNo, dsu, temp) =>
        for disk in temp
            if disk.location is "#{dsu.location}.#{slotNo}"
                info = health:disk.health, cap_sector:disk.cap_sector, \
                role:disk.role, raid:disk.raid, vendor:disk.vendor, \
                sn:disk.sn, model:disk.model, type:disk.type
                return info
        'none'
        
    _has_disk: (slotNo, dsu, dsu_disk_num,temp) =>
        loc = "#{dsu_disk_num + slotNo}"
        for disk in temp
            if disk.location is "#{dsu.location}.#{slotNo}"
                rdname = if disk.raid is ""\
                    then "noraid"\
                    else disk.raid
                rdrole = if disk.health is "down"\
                    then "down"\
                    else disk.role
                o = slot: loc, role:rdrole, raid:rdname, raidcolor: ""
                return o
        o = slot: loc, role:"nodisk", raid:"noraid", raidcolor: ""
        return o

    _get_raid_color_map: (temp) =>
        map = {}
        raids = []
        i = 1
        has_global_spare = false
        for disk in temp
            if disk.role is "global_spare"
                has_global_spare = true
                continue
            rdname = if disk.raid is ""\
                then "noraid"\
                else disk.raid
            if rdname not in raids
                raids.push rdname
        for raid in raids
            map[raid] = "color#{i}"
            i = i + 1
        map["noraid"] = "color0"
        if has_global_spare is true
            map["global_spare"] = "color5"
        return map

    test: () =>
        return [[{raid: "normal",raidcolor: "color0",role: "unused",slot:"1"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"2"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"3"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"4"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"5"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"6"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"7"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"8"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"9"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"10"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"11"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"12"}],\
        [{raid: "normal",raidcolor: "color0",role: "unused",slot:"13"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"14"},\
        {raid: "normal",raidcolor: "color0",role: "unused",slot:"15"},{raid: "normal",raidcolor: "color0",role: "unused",slot:"16"}]]

    _compare: (propertyname) =>
        (obj1, obj2) =>
            value1 = obj1[propertyname]
            value2 = obj2[propertyname]
            if value1 < value2
                return -1
            else if value1 > value2
                return 1
            else 
                return 0    

class CentralServerDetailPage extends Page
    constructor: (@sd, @page, @device, @switch_to_page, @message) ->
        super "centralserverdetailpage-", "html/centralserverdetailpage.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                latest = source.items[source.items.length - 1]
                for i in latest.exports
                    if i.ip is @device.name
                        @vm.cpu_load = parseInt i.info[0].cpu
                        @vm.mem_load = parseInt i.info[0].mem
                        
                        @refresh_df(i.info[0])
                        @refresh_mini_chart(i.info[0])
                        
                        #@sparkline_stats system,temp,cap
                        #@refresh_flow()
                        
        $(@sd.journals).on "updated", (e, source) =>
            @vm.journal = @subitems_log()
            
    define_vm: (vm) =>
        vm.lang = lang.centraldisk
        vm.switch_to_page = @switch_to_page
        vm.cpu_load = 0
        vm.cache_load = 0
        vm.cap_load = 0
        vm.flow_type = "fwrite_mb"
        vm.mem_load = 0
        
        vm.per_docker = 0
        vm.per_tmp = 0
        vm.per_var = 0
        vm.per_system = 0
        vm.per_weed_cpu = 0
        vm.per_weed_mem = 0
        
        vm.tabletitle = @device.name
        
        vm.$watch "cpu_load", (nval, oval) =>
            $("#cpu-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "per_system", (nval, oval) =>
            $("#system-load").data("easyPieChart").update?(nval) if @has_rendered
            return
        vm.$watch "mem_load", (nval, oval) =>
            $("#mem-load").data("easyPieChart").update?(nval) if @has_rendered
            return            
        vm.$watch "cap_load", (nval, oval) =>
            $("#cap-load").data("easyPieChart").update?(nval) if @has_rendered
            return
            
        vm.fattr_journal_status = fattr.journal_status
        vm.journal = @subitems_log()
        vm.journal_info = @subitems_info()
        vm.journal_warning = @subitems_warning()
        vm.journal_critical = @subitems_critical()
        vm.rendered = @rendered
        vm.fattr_monitor_status = fattr.monitor_status
        vm.fattr_view_status_fixed = fattr.view_status_fixed
        
    rendered: () =>
        super()
        new WOW().init();
        #@refresh_pie @sd
        opt1 = animate: 1000, size: 80, lineWidth: 3, lineCap: "butt", barColor: "rgb(87, 199, 212)",trackColor: 'rgba(87, 199, 212,0.1)',scaleColor: false
        opt2 = animate: 1000, size: 80, lineWidth: 5, lineCap: "butt", barColor: "rgb(98, 168, 234)",trackColor: 'rgba(98, 168, 234,0.1)',scaleColor: false
        opt3 = animate: 1000, size: 80, lineWidth: 5, lineCap: "butt", barColor: "rgb(146, 109, 222)",trackColor: 'rgba(146, 109, 222,0.1)',scaleColor: false
        opt4 = animate: 1000, size: 80, lineWidth: 5, lineCap: "butt", barColor: "rgb(146, 109, 222)",trackColor: 'rgba(146, 109, 222,0.1)',scaleColor: false
        
        try
            $("#cpu-load").easyPieChart opt1
            $("#cpu-load").data("easyPieChart").update? @vm.cpu_load
            $("#system-load").easyPieChart opt1
            $("#system-load").data("easyPieChart").update? @vm.per_system
            $("#mem-load").easyPieChart opt1
            $("#mem-load").data("easyPieChart").update? @vm.mem_load
            
            $("#cap-load").easyPieChart opt1
            $("#cap-load").data("easyPieChart").update? @vm.cap_load
        catch e
            return
        
        @data_table1 = $("#log-table1").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table2 = $("#log-table2").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table3 = $("#log-table3").dataTable dtable_opt(retrieve: true, bSort: false)
        @data_table4= $("#log-table4").dataTable dtable_opt(retrieve: true, bSort: false)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller1 = $("#journals-scroller-1")
        $scroller2 = $("#journals-scroller-2")
        $scroller3 = $("#journals-scroller-3")
        $scroller4 = $("#journals-scroller-4")
        
        $scroller1.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller1.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller2.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller2.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller3.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller3.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
        $scroller4.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller4.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
        #@refresh_flow()
        #@sparkline_stats 10,50,90
        try
            @plot_flow_in @sd.stats.items,@device.name
            @mini_chart()
        catch e
            console.log e
            
    subitems_log: () =>
        try
            arrays = []
            for i in @sd.machinedetails.items
                if i.uuid is @message
                   arrays = i.journals
            for t in arrays
                t.created = t.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
            arrays.reverse()
        catch error
            return []
        
    subitems_info: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'info')
        info
            
    subitems_warning: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'warning')
        info
            
    subitems_critical: () =>
        info = []
        ((info.push i) for i in @subitems_log() when i.level is 'critical')
        info
        
    refresh_df:(items) =>
        dist = {'cache':0,'docker':0,'tmp':0,'var':0,'system':0,'weed_cpu':0,'weed_mem':0}
        total_used = 0
        for i in items.df
            dist[i.name] = i.used_per
        
        if items.fs.length
            for h in items.fs
                total_used = total_used + h.used_per
            @vm.cap_load = parseInt(total_used/items.fs.length)
        else
            @vm.cap_load = 0
            
        @vm.per_docker = parseInt dist.docker
        @vm.per_tmp = parseInt dist.tmp
        @vm.per_var = parseInt dist.var
        @vm.per_system = parseInt dist.system
        @vm.per_weed_cpu = parseInt dist.weed_cpu
        @vm.per_weed_mem = parseInt dist.weed_mem
    
    refresh_mini_chart:(items) =>
        try
            dist = {'weed_cpu':0,'weed_mem':0,'docker':0,'var':0,'tmp':0};
            for i in items.df
                dist[i.name] = i.used_per

            conf_docker = {
                      "type": "pie",
                      "dataProvider": [ {
                        "x": 1,
                        "value": 100-dist.docker
                      }, {
                        "x": 2,
                        "value": dist.docker
                      } ],
                      "labelField": "x",
                      "valueField": "value",
                      "labelsEnabled": false,
                      "balloonText": "",
                      "valueText": undefined,
                      "radius": 9,
                      "outlineThickness": 1,
                      "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                      "startDuration": 0
                    };
                    
            conf_tmp = {
                          "type": "pie",
                          "dataProvider": [ {
                            "x": 1,
                            "value": 100-dist.tmp
                          }, {
                            "x": 2,
                            "value": dist.tmp
                          } ],
                          "labelField": "x",
                          "valueField": "value",
                          "labelsEnabled": false,
                          "balloonText": "",
                          "valueText": undefined,
                          "radius": 9,
                          "outlineThickness": 1,
                          "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                          "startDuration": 0
                        };
                        
            conf_var = {
                          "type": "pie",
                          "dataProvider": [ {
                            "x": 1,
                            "value": 100-dist.var
                          }, {
                            "x": 2,
                            "value": dist.var
                          } ],
                          "labelField": "x",
                          "valueField": "value",
                          "labelsEnabled": false,
                          "balloonText": "",
                          "valueText": undefined,
                          "radius": 9,
                          "outlineThickness": 1,
                          "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                          "startDuration": 0
                        };
                        
            conf_system_cap = {
                          "type": "pie",
                          "dataProvider": [ {
                            "x": 1,
                            "value": 100-dist.system
                          }, {
                            "x": 2,
                            "value": dist.system
                          } ],
                          "labelField": "x",
                          "valueField": "value",
                          "labelsEnabled": false,
                          "balloonText": "",
                          "valueText": undefined,
                          "radius": 9,
                          "outlineThickness": 1,
                          "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                          "startDuration": 0
                        };
                        
            conf_weed_cpu = {
                          "type": "pie",
                          "dataProvider": [ {
                            "x": 1,
                            "value": 100-dist.weed_cpu
                          }, {
                            "x": 2,
                            "value": dist.weed_cpu
                          } ],
                          "labelField": "x",
                          "valueField": "value",
                          "labelsEnabled": false,
                          "balloonText": "",
                          "valueText": undefined,
                          "radius": 9,
                          "outlineThickness": 1,
                          "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                          "startDuration": 0
                        };
                        
            conf_weed_mem = {
                          "type": "pie",
                          "dataProvider": [ {
                            "x": 1,
                            "value": 100-dist.weed_mem
                          }, {
                            "x": 2,
                            "value": dist.weed_mem
                          } ],
                          "labelField": "x",
                          "valueField": "value",
                          "labelsEnabled": false,
                          "balloonText": "",
                          "valueText": undefined,
                          "radius": 9,
                          "outlineThickness": 1,
                          "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                          "startDuration": 0
            }
            AmCharts.makeChart( "mini_docker_serdetail", conf_docker );
            AmCharts.makeChart( "mini_var_serdetail", conf_var );
            AmCharts.makeChart( "mini_tmp_serdetail", conf_tmp );
            #AmCharts.makeChart( "mini_system_serdetail", conf_system_cap );
            AmCharts.makeChart( "mini_weed_cpu_serdetail", conf_weed_cpu );
            AmCharts.makeChart( "mini_weed_mem_serdetail", conf_weed_mem );            
        catch e
            return

    mini_chart:() =>
        defaults = {
                "type": "pie",
                "dataProvider": [ {
                   "x": 1,
                   "value": 100
                }, {
                   "x": 2,
                   "value": 0
                } ],
                "labelField": "x",
                "valueField": "value",
                "labelsEnabled": false,
                "balloonText": "",
                "valueText": undefined,
                "radius": 9,
                "outlineThickness": 1,
                "colors": [ "rgba(98, 168, 234,0.8)", "rgb(28, 123, 213)" ],
                "startDuration": 0
            };
        AmCharts.makeChart( "mini_docker_serdetail", defaults );
        AmCharts.makeChart( "mini_var_serdetail", defaults );
        AmCharts.makeChart( "mini_tmp_serdetail", defaults );
        #AmCharts.makeChart( "mini_system_serdetail", defaults );
        AmCharts.makeChart( "mini_weed_cpu_serdetail", defaults );
        AmCharts.makeChart( "mini_weed_mem_serdetail", defaults );   
        
    sparkline_stats: (system,temp,cap) =>
        arm =
            chart: 
                type: 'column'
            title: 
                text: ''
                verticalAlign: "bottom"
                style: 
                    color: '#000'
                    fontFamily: 'Microsoft YaHei'
                    fontSize:16
            subtitle: 
                text: ''
            xAxis:
                type: 'category'
                gridLineColor: '#FFF'
                tickColor: '#FFF'
                labels: 
                    enabled: false
                    rotation: -45
                    style: 
                        fontSize: '13px'
                        fontFamily: 'Verdana, sans-serif'
            yAxis: 
                gridLineColor: '#FFF'
                min: 0
                title: 
                    text: ''
                labels: 
                    enabled: false
            credits: 
                enabled:false
            exporting: 
                enabled: false
            legend: 
                enabled: false
            tooltip: 
                pointFormat: '<b>{point.y:.1f}</b>'
            plotOptions: 
                column: 
                    animation:false,
                    pointPadding: 0.01,
                    groupPadding: 0.01,
                    borderWidth: 0.01,
                    shadow: false,
                    pointWidth: 7
            series: [{
                name: 'Population'
            }]

        $('#sparkline_bar1').highcharts(Highcharts.merge(arm,
            title: 
                text: '处理器'
            plotOptions: 
                column: 
                    color: '#35aa47'
            series: [{
                data: [
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9],
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9]
                ]
            }]
        ))
        $('#sparkline_bar2').highcharts(Highcharts.merge(arm, 
            title: 
                text: '系统空间'
            plotOptions: 
                column: 
                    color: '#ffb848'
            series: [{
                data: [
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9],
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9]
                ]
            }]
        ))
        
        $('#sparkline_bar3').highcharts(Highcharts.merge(arm, 
            title: 
                text: '内存'
            plotOptions: 
                column: 
                    color: '#e7505a'
            series: [{
                data: [
                    ['Lima', 8.9],
                    ['Karachi', 14.0],
                    ['Jakarta', 10.0],
                    ['Tokyo', 9.0],
                    ['Cairo', 8.9],
                    ['Shanghai', 23.7],
                    ['Lagos', 16.1],
                    ['Instanbul', 14.2],
                    ['Kinshasa', 9.3],
                    ['Tianjin', 9.3],
                    ['Dhaka', 8.9],
                    ['Mexico City', 8.9]
                ]
            }]
        ))
        
    subitems: () =>
        return []
        
    refresh_flow: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].exports
                if i.ip is @device.name
                    @plot_flow_in i.info
                    @plot_flow_out i.info
        catch e
            console.log e
            
    refresh: () =>
        try
            for i in @sd.stats.items[@sd.stats.items.length - 1].exports
                if i.ip is @device.name
                    @vm.cpu_load = i.info[i.info.length - 1].cpu
                    @vm.mem_load = i.info[i.info.length - 1].mem
                    @vm.cache_load = i.info[i.info.length - 1].df[0].used_per
        catch e
            console.log e
        
    refresh_pie: (sd) =>
        $(`function () {
            var gaugeOptions = {
                chart: {
                    type: 'gauge',
                    plotBackgroundColor: null,
                    plotBackgroundImage: null,
                    plotBorderWidth: 0,
                    plotShadow: false
                },
                exporting: {
                    enabled: false
                },
                credits: {
                    enabled:false
                },
                title: {
                    style:{
                        fontWeight:'bold',
                        fontSize:19,
                        color:'#000'
                    }
                },
                pane: {
                    startAngle: -150,
                    endAngle: 150,
                    background: [{
                        backgroundColor: {
                            linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                            stops: [
                                [0, '#FFF'],
                                [1, '#333']
                            ]
                        },
                        borderWidth: 0,
                        outerRadius: '109%'
                    }, {
                        backgroundColor: {
                            linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                            stops: [
                                [0, '#333'],
                                [1, '#FFF']
                            ]
                        },
                        borderWidth: 1,
                        outerRadius: '107%'
                    }, {
                        // default background
                    }, {
                        backgroundColor: '#DDD',
                        borderWidth: 0,
                        outerRadius: '105%',
                        innerRadius: '103%'
                    }]
                },
                // the value axis
                yAxis: {
                    min: 0,
                    max: 100,
                    minorTickInterval: 'auto',
                    minorTickWidth: 1,
                    minorTickLength: 10,
                    minorTickPosition: 'inside',
                    minorTickColor: '#666',
                    tickPixelInterval: 30,
                    tickWidth: 2,
                    tickPosition: 'inside',
                    tickLength: 10,
                    tickColor: '#666',
                    labels: {
                        step: 2,
                        rotation: 'auto'
                    },
                    title: {
                        text: '%'
                    },
                    plotBands: [{
                        from: 0,
                        to: 120,
                        color: '#55BF3B' // green
                    }, {
                        from: 120,
                        to: 160,
                        color: '#DDDF0D' // yellow
                    }, {
                        from: 160,
                        to: 200,
                        color: '#DF5353' // red
                    }]
                }
            };
            $('#container_cpu').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'处理器'
                    },
                    series: [{
                        name: '处理器',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
                
            $('#container_cache').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'缓存'
                    },
                    series: [{
                        name: '缓存',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
                
            $('#container_mem').highcharts(Highcharts.merge(gaugeOptions, {
                    title: {
                        text:'内存'
                    },
                    series: [{
                        name: '内存',
                        data: [0],
                        tooltip: {
                            valueSuffix: '%'
                        }
                    }]
                }));
            setInterval(function () {
                // cpu
                var latest = sd.stats.items[sd.stats.items.length-1];
                var cpu_load  = parseInt(latest.cpu);
                var cache_load  = parseInt(latest.cache);
                var mem_load = parseInt(latest.mem);
                
                var chart = $('#container_cpu').highcharts(),
                    point,
                    newVal,
                    inc;
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(cpu_load);
                }
                
                // cache
                chart = $('#container_cache').highcharts();
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(cache_load);
                }
                
                //mem
                chart = $('#container_mem').highcharts();
                if (chart) {
                    point = chart.series[0].points[0];
                    point.update(mem_load);
                }
            }, 2000);
        }`);
           
    plot_flow_in: (yaxis, name) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_in', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    //plotBorderColor:"rgb(235, 235, 235)",
                    //plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_in_interval_detail_ser = setInterval(function () {
                                try{
                                    var type1 = 'write_mb';
                                    var type2 = 'read_mb';
                                    var x = (new Date()).getTime(); // current time
                                    var y1 = 0;
                                    var y2 = 0;
                                    for (var i=0;i< yaxis[yaxis.length - 1].exports.length;i++){
                                        if( yaxis[yaxis.length - 1].exports[i].ip == name){
                                            y1 = yaxis[yaxis.length - 1].exports[i].info[0][type1];
                                            y2 = yaxis[yaxis.length - 1].exports[i].info[0][type2];
                                        }
                                    };
                                    var random1 = Math.random();
                                    var random2 = Math.random();
                                    //series1.addPoint([x, y1 + random1], true, true);
                                    //series2.addPoint([x, -(y2 + random2)], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_in_interval_detail_ser);
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    lineWidth:0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    //maxPadding: 2,
                    //tickAmount: 4,
                    //allowDecimals:false,
                    gridLineColor: "#FFF",
                    //min:-1,
                    //max:150,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 0,
                        color: '#808080'
                    }],
                    labels: {
                        formatter: function () {
                           if (this.value < 0){
                               return -(this.value);
                           }else{
                             return this.value;
                           }
                        }
                    }
                },
                tooltip: {
                    formatter: function () {
                        if (this.y < 0){
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(-(this.y), 2);
                        }else{
                            return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                        }
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000',
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: true,
                    layout: 'horizontal',
                    backgroundColor: 'rgba(0,0,0,0)',
                    align: 'right',
                    verticalAlign: 'top',
                    floating: true,
                    itemStyle: {
                        color: 'rgb(141,141,141)',
                        fontWeight: '',
                        fontFamily:"Microsoft YaHei"
                    }
                },
                exporting: {
                    enabled: false
                },
                colors:["#77d6e1","rgb(98, 168, 234)"],
                //colors:["#a58add","#77d6e1"],
                plotOptions: {
                    areaspline: {
                        //threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 1
                            }
                        },
                        fillOpacity: 0.4,
                        //fillColor:"rgba(227,91,90,0.4)",
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 1,
                            lineWidth:1,
                            lineColor:"#fff",
                            //fillColor:"rgba(255,120,120,0.7)",
                            /*states: {
                                hover: {
                                    enabled: true,
                                    fillColor:"rgb(227,91,90)"
                                }
                            }*/
                        },
                        lineWidth: 2,
                        //lineColor:"rgba(227,91,90,0.5)"
                    }
                },
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: Math.random()
                                    y: prety[-i]
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            var prety = [0,0.1,0.24,0.38,0.4,0.5,0.41,0.32,0.29,0,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.51,1.52,1.51,1.50,1.0,0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1,0];
                            for (i = -29; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    //y: -(Math.random())
                                    y: -(prety[-i])
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#net_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#net_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);

    plot_flow_out: (yaxis) =>
        $(document).ready(`function () {
            Highcharts.setOptions({
                global: {
                    useUTC: false
                }
            });
            var chart = Highcharts.chart('flow_stats_out', {
                chart: {
                    type: 'areaspline',
                    //animation:false,
                    animation: Highcharts.svg, // don't animate in old IE
                    marginRight: 10,
                    plotBorderColor:"rgb(255, 255, 255)",
                    plotBorderWidth:1,
                    //backgroundColor:"rgb(250, 250, 250)",
                    events: {
                        load: function () {
                            var series1 = this.series[0];
                            var series2 = this.series[1];
                            var flot_out_interval_detail_ser = setInterval(function () {
                                try{
                                    var type1 = 'write_vol';
                                    var type2 = 'read_vol';
                                    var random = Math.random();
                                    var x = (new Date()).getTime(), // current time
                                        y1 = yaxis[yaxis.length - 1][type1];
                                        y2 = yaxis[yaxis.length - 1][type2];
                                    //series1.addPoint([x, y1 + random], true, true);
                                    //series2.addPoint([x, y2 + random], true, true);
                                    series1.addPoint([x, y1], true, true);
                                    series2.addPoint([x, -(y2)], true, true);
                                }
                                catch(e){
                                    return;
                                }
                            }, 3000);
                            global_Interval.push(flot_out_interval_detail_ser);
                            //series2.hide();
                        }
                    }
                },
                title: {
                    text: ''
                },
                xAxis: {
                    tickWidth: 0,
                    labels: {
                        enabled: false
                    },
                    type: 'datetime',
                    tickPixelInterval: 150
                },
                yAxis: {
                    maxPadding: 2,
                    tickAmount: 4,
                    min:-1,
                    title: {
                        text: ''
                    },
                    plotLines: [{
                        value: 0,
                        width: 1,
                        color: '#808080'
                    }]
                },
                tooltip: {
                    formatter: function () {
                        return '<b>' + this.series.name + '</b><br/>' +
                            Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', this.x) + '<br/>' +
                            Highcharts.numberFormat(this.y, 2);
                    },
                    style: {
                        color:'#fff',
                        fontSize:'12px',
                        opacity:0.8
                    },
                    borderRadius:0,
                    borderColor:'#000',
                    backgroundColor:'#000'
                },
                credits: {
                    enabled:false
                },
                legend: {
                    enabled: false
                },
                exporting: {
                    enabled: false
                },
                plotOptions: {
                    areaspline: {
                        threshold: null,
                        //animation:false,
                        states: {
                            hover: {
                                lineWidth: 2
                            }
                        },
                        fillOpacity: 0.2,
                        marker: {
                            enabled: false,
                            symbol: 'circle',
                            radius: 4.5,
                            fillColor:"rgb(143, 208, 253)",
                            states: {
                                hover: {
                                    enabled: true
                                }
                            }
                        },
                        lineWidth: 2
                    }
                },
                colors:["rgb(115, 172, 240)","rgb(115, 172, 240)"],
                series: [{
                    name: '写流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                },{
                    name: '读流量',
                    data: (function () {
                        // generate an array of random data
                        try{
                            var data = [],
                                time = (new Date()).getTime(),
                                i;
                            for (i = -9; i <= 0; i += 1) {
                                data.push({
                                    x: time + i * 1000,
                                    y: Math.random()
                                });
                            }
                            return data;
                        }
                        catch(e){
                            return;
                        }
                    }())
                }]
            });
            $('#vol_write').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.show();
                series2.hide();
            });
            $('#vol_read').click(function () {
                var series1 = chart.series[0];
                var series2 = chart.series[1];
                series1.hide();
                series2.show();
            });
        }`);
        
    
##################################################################

class CentralServerlistPage extends DetailTablePage
    constructor: (@sd) ->
        super "centralpage-server-list", "html/centralserverlistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        table_update_listener @sd.clouds, "#server-table", =>
            @vm.devices = @subitems() if not @has_frozen

    define_vm: (vm) =>
        vm.devices = @subitems()
        vm.lang = lang.central_server_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        vm.start = @start
        vm.combine = @combine
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#server-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:"",role:""
        sub = []
        for i in arrays
            if i.devtype is 'export'
                i.name = '服务器'
                i.id = i.uuid
                if i.role is ""
                    i.Role = "无"
                    i.show_combine = true
                else if i.role is "master"
                    i.Role = "主"
                    i.show_combine = false
                else if i.role is "backup"
                    i.Role = "备"
                    i.show_combine = false
                sub.push i
        sub
            
    detail_html: (server) =>
        html = avalon_templ server.id, "html/server_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is server.id
                o = i
        vm = avalon.define server.id, (vm) =>
            vm.stores = subitems @sd.server_stores(o),ip:"",node:"",location:""
            vm.lang = lang.central_server_list
        return [html, vm]
            
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    create_mysql: () =>
        (new CentralCreateServerModal(@sd, this)).attach()
    
    combine: (master) =>
        (new CentralCombineServerModal(@sd, this, master)).attach()
        
    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
        
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "export",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    start:(ip) =>
        (new CentralStartModal(@sd, this, ip)).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralStorelistPage extends DetailTablePage
    constructor: (@sd) ->
        super "centralpage-store-list", "html/centralstorelistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
            
        table_update_listener @sd.clouds, "#store-table", =>
            @vm.devices = @subitems() if not @has_frozen
            
    define_vm: (vm) =>
        vm.devices = @subitems() 
        vm.lang = lang.central_store_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.pre = @pre
        vm.mount = @mount
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        
    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#store-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:""
        sub = []
        for i in arrays
            if i.devtype is 'storage'
                i.name = '存储'
                i.id = i.uuid
                if i.master is ""
                    i.master = '无'
                sub.push i
        sub
            
    detail_html: (store) =>
        html = avalon_templ store.id, "html/store_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is store.id
                o = i
        vm = avalon.define store.id, (vm) =>
            vm.servers = subitems @sd.store_servers(o),ip:""
            vm.lang = lang.central_store_list
        return [html, vm]
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
    create_mysql: () =>
        (new CentralCreateStoreModal(@sd, this)).attach()
    
    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
    
    mount: (ip,name) =>
        (new ConfirmModal @vm.lang.mount, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozoset name,ip,""
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.mount_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "storage",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralClientlistPage extends Page
    constructor: (@sd) ->
        super "centralpage-client-list", "html/centralclientlistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
        table_update_listener @sd.clouds, "#client-table", =>
            @vm.devices = @subitems() if not @has_frozen
            
    define_vm: (vm) =>
        vm.devices = @subitems()
        vm.lang = lang.central_client_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.start = @start
        vm.pre = @pre
        vm.expand = @expand
        vm.start = @start
        vm.combine = @combine
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record

    rendered: () =>
        super()
        $('.tooltips').tooltip()
        @vm.devices = @subitems() if not @has_frozen
        @data_table = $("#client-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:""
        sub = []
        for i in arrays
            if i.devtype is 'client'
                i.id = i.uuid
                i.name = '客户端'
                sub.push i
        sub
    
    combine: (master) =>
        (new CentralCombineServerModal(@sd, this, master)).attach()
        
    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
    create_mysql: () =>
        (new CentralCreateClientModal(@sd, this)).attach()
        
    start: (ip) =>
        (new ConfirmModal @vm.lang.start, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).client ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.start_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop 'client',ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralWarningPage extends DetailTablePage
    constructor: (@sd,@switch_to_page) ->
        super "maintainpage-", "html/centralwarning.html"
        @settings = new SettingsManager
    define_vm: (vm) =>
     
        vm.lang = lang.central_warning
        vm.diagnosis_url = "http://#{@sd.host}/api/diagnosis/all"
        vm.devices = @subitems()
        vm.emails = @subitems_email()
        vm.add = @add
        vm.change_value = @change_value
        vm.removes = @removes
        vm.change_email = @change_email
        vm.all_checked = false
        vm.switch_to_page = @switch_to_page
        vm.$watch "all_checked", =>
            for r in vm.emails
                r.checked = vm.all_checked
    rendered: () =>
        super()
        @vm.devices = @subitems()
        @vm.emails = @subitems_email()
        @nprocess()
        PortletDraggable.init()
        ###$('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target',
            alignX: 'center',
            alignY: 'bottom',
            offsetY: 0,
            allowTipHover: false,
            fade: false
        )###
    
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),10
            
    subitems_email: () =>
        tmp = []
        for i in @sd.emails.items
            i.checked = false
            if i.level is 1
                i.chinese_level = "低"
            else if i.level is 2
                i.chinese_level = "中"
            else
                i.chinese_level = "高"
            tmp.push i
        tmp
        
    subitems: () =>
        tmp = []
        ###for i in @sd.warnings.items
            i.bad = i.warning
            if i.type is "cpu"
                i.chinese_type = "处理器"
            #if i.type is "diskcap"
            #    i.chinese_type = "元素据容量"
            else if i.type is "cache"
                i.chinese_type = "缓存"
            else if i.type is "mem"
                i.chinese_type = "内存"
            else if i.type is "filesystemCap"
                i.chinese_type = "文件系统容量"
            else if i.type is "systemCap"
                i.chinese_type = "系统盘容量"
            else if i.type is "dockerCap"
                i.chinese_type = "docker文件夹容量"
            else if i.type is "tmpCap"
                i.chinese_type = "tmp文件夹容量"
            else if i.type is "weedCpu"
                i.chinese_type = "weed处理器"
            else if i.type is "weedMem"
                i.chinese_type = "weed内存"
            else if i.type is "varCap"
                i.chinese_type = "var文件夹容量"
            else
                continue
            tmp.push i###
            
        for i in @sd.warnings.items
            if i.type is "export"
                i.apply = "服务器"
            else
                i.apply = "存储"
               
            tmp.push i
        #console.log tmp
        tmp
        
    add: () =>
        (new CentralAddEmailModal(@sd, this)).attach()
        
    removes: () =>
        deleted = ($.extend({},r.$model) for r in @vm.emails when r.checked)
        if deleted.length isnt 0   
            (new CentralEmailDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    change_value: (warn_type,apply,normal,bad,uid) =>
        (new CentralChangeValueModal(@sd, this, warn_type,apply,normal,bad,uid)).attach()
        
    change_email: (uid) =>
        (new CentralChangeEmailModal(@sd, this, uid)).attach()
        

class CentralMachinelistPage extends DetailTablePage
    constructor: (@sd, @switch_to_page) ->
        super "centralmachinelistpage-", "html/centralmachinelistpage.html"
        
        table_update_listener @sd.clouds, "#store-table", =>
            @vm.devices = @subitems()
            
    define_vm: (vm) =>
        vm.devices = @subitems() 
        vm.lang = lang.central_store_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.pre = @pre
        vm.mount = @mount
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        vm.open_client = @open_client
        vm.close_client = @close_client
        vm.init_all = @init_all
        vm.switch_to_page = @switch_to_page
        
    rendered: () =>
        super()
        PortletDraggable.init()
        $('.tooltips').tooltip()
        @vm.devices = @subitems() if not @has_frozen
        @data_table = $("#store-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        ###$('input').iCheck(
            checkboxClass: 'icheckbox_minimal',
            radioClass: 'iradio_minimal',
            increaseArea: '20%'
        )
        $('#all_checked').on 'ifChecked',(event) =>
            $('input').iCheck('check')
        $('#all_checked').on 'ifUnchecked', (event) =>
            $('input').iCheck('uncheck')###
        @nprocess()
    
    init_all:() =>
        return
        
    open_client:(ip,name) =>
        if name is "client"
            (new ConfirmModal @vm.lang._start, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).client ip
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_machine_list.start_success)).attach()
                    @attach()
            ).attach()
            
    
    close_client:(ip,name) =>
        if name is "client"
            (new ConfirmModal @vm.lang._stop, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).rozostop name,ip
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_machine_list.stop_success)).attach()
                    @attach()
            ).attach()
                
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),10
       
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:"",\
                role:"",cluster:""
        sub = []
        for i in arrays
            if i.devtype is 'storage'
                i.name = '存储'
                sub.push i
            else if i.devtype is 'export'
                if i.role is "master"
                    i.name = '主服务器'
                else if i.role is "backup"
                    i.name = "备份服务器"
                else
                    i.name = "服务器"
                sub.push i
            else
                i.name = '客户端'
                i.id = i.uuid
               
            if i.cluster is ""
                i.cluster = "无"
        sub
            
    detail_html: (store) =>
        html = avalon_templ store.id, "html/store_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is store.id
                o = i
        vm = avalon.define store.id, (vm) =>
            vm.servers = subitems @sd.store_servers(o),ip:""
            vm.lang = lang.central_store_list
        return [html, vm]
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            for i in deleted
                if i.cluster isnt "无"
                    return (new MessageModal('请先解除机器的集群')).attach()
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    create_mysql: () =>
        (new CentralCreateMachineModal(@sd, this)).attach()
    
    expand: (ip) =>
        (new CentralExpandModal(@sd, this, ip)).attach()
    
    mount: (ip,name) =>
        (new ConfirmModal @vm.lang.mount, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozoset name,ip,""
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.mount_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "storage",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
class CentralStartlistPage extends DetailTablePage
    constructor: (@sd) ->
        super "centralstartlistpage-", "html/centralstartlistpage.html"
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.devices = @subitems()
            @vm.options_export = @options_export()
            @vm.options_client = @options_client()
            @vm.options_backup = @options_backup()
            
        table_update_listener @sd.clouds, "#store-table", =>
            @vm.devices = @subitems() if not @has_frozen
            
    define_vm: (vm) =>
        vm.devices = @subitems() 
        vm.lang = lang.central_machine_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.pre = @pre
        vm.mount = @mount
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.storages
                r.checked = vm.all_checked
                
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        vm.combine = @combine
        
        vm.storage_ip = ""
        
        vm.options_export = @options_export()
        vm.options_client = @options_client()
        vm.options_backup = @options_backup()
        
        vm.expand_success = false
        vm.expand_result = "扩容即在服务器下添加存储以增加集群的容量"
        vm.option = "uncombine"
        vm.storages = @storages()
        vm.next_action = "扩容"
        vm.action_tips = "请选择机器地址"
        vm.start = @start
        vm._checkbox = @_checkbox
        
    rendered: () =>
        super()
        PortletDraggable.init()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#store-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        @initpage(this)
        $("#export_option").chosen()
        $("#client_option").chosen()
        @vm.options_export = @options_export()
        @vm.options_client = @options_client()
        @vm.options_backup = @options_backup()
        @vm.storage_ip = ""
        @vm.expand_success = false
        @vm.expand_result = "扩容即在服务器下添加存储以增加集群的容量"
        @vm.storages = @storages()
        @vm.next_action = "扩容"
        @vm.action_tips = "请选择机器地址"
        ###$('input').iCheck(
            checkboxClass: 'icheckbox_minimal',
            radioClass: 'iradio_minimal',
            increaseArea: '20%'
        )
        $('#all_checked').on 'ifChecked',(event) =>
            $('input').iCheck('check')
        $('#all_checked').on 'ifUnchecked', (event) =>
            $('input').iCheck('uncheck')###
        @nprocess()
    
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),10
        
    storages:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:""
        sub = []
        for i in arrays
            if i.devtype is 'storage' and !i.status
                i.name = '存储'
                sub.push i
        sub
        
    _checkbox:(i) =>
        if i.ip is "请选择"
            for r in @vm.storages
                    r.checked = !i.checked
        
    initpage: (page) =>
        $(`function() {
            $('#form_wizard_1').bootstrapWizard({
                'nextSelector': '.button-next',
                'previousSelector': '.button-previous',
                onTabClick: function (tab, navigation, index) {
                    //alert('on tab click disabled');
                    return false;
                },
                onNext: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    if (current == 2){
                        var sub = [];
                        for (i = 0, len = page.vm.storages.length; i < len; i++) {
                            tmp = page.vm.storages[i];
                            if (tmp.checked) {
                                sub.push(tmp);
                            }
                        }
                        if (sub.length == 0 || $("#export_option").val() == "no" || $("#client_option").val() == "no"){
                            $('.alert-error', $('#submit_form')).show();
                            return false;
                        }else{
                            page.expand();
                            page.vm.next_action = "跳过";
                            $('.alert-error', $('#submit_form')).hide();
                        }
                    }else if (current == 3){
                        page.vm.next_action = "开启";
                    }else{
                        page.start();
                    }
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        $('#form_wizard_1').find('.button-previous').hide();
                    } else {
                        $('#form_wizard_1').find('.button-previous').show();
                    }
                    //console.log(page.vm.show_card_result);
                    if (current >= total) {
                        //$('#form_wizard_1').find('.button-next').hide();
                        //$('#form_wizard_1').find('.button-submit').show();
                        //displayConfirm();
                    } else {
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }
                    //App.scrollTo($('.page-title'));
                },
                onPrevious: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    $('.alert-error', $('#submit_form')).hide();
                    // set wizard title
                    $('.step-title', $('#form_wizard_1')).text('Step ' + (index + 1) + ' of ' + total);
                    // set done steps
                    jQuery('li', $('#form_wizard_1')).removeClass("done");
                    var li_list = navigation.find('li');
                    for (var i = 0; i < index; i++) {
                        jQuery(li_list[i]).addClass("done");
                    }

                    if (current == 1) {
                        page.vm.next_action = "扩容";
                        $('#form_wizard_1').find('.button-previous').hide();
                    } else {
                        page.vm.next_action = "跳过";
                        $('#form_wizard_1').find('.button-previous').show();
                    }

                    if (current >= total) {
                        $('#form_wizard_1').find('.button-next').hide();
                        $('#form_wizard_1').find('.button-submit').show();
                    } else {
                        $('#form_wizard_1').find('.button-next').show();
                        $('#form_wizard_1').find('.button-submit').hide();
                    }

                    //App.scrollTo($('.page-title'));
                },
                onTabShow: function (tab, navigation, index) {
                    var total = navigation.find('li').length;
                    var current = index + 1;
                    var $percent = (current / total) * 100;
                    $('#form_wizard_1').find('.bar').css({
                        width: $percent + '%'
                    });
                }
            });

            $('#form_wizard_1').find('.button-previous').hide();
            $('#form_wizard_1 .button-submit').click(function () {
                page.attach();
            }).hide();
        }`)
        
    subitems: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:""
        sub = []
        for i in arrays
            if i.devtype is 'storage'
                i.name = '存储'
            else if i.devtype is 'export'
                i.name = '服务器'
            else
                i.name = '客户端'
                i.id = i.uuid
            sub.push i
        sub
            
    options_export: () =>
        options = [{key:'请选择',value:'no'}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'export' and !i.status)
        options
        
    options_backup: () =>
        options = [{key:'请选择',value:'no'}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'export' and !i.status)
        options
        
    options_client: () =>
        options = [{key:'请选择',value:'no'}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'client' and !i.status)
        options
        
    detail_html: (store) =>
        html = avalon_templ store.id, "html/store_detail_row.html"
        for i in @sd.clouds.items
            if i.uuid is store.id
                o = i
        vm = avalon.define store.id, (vm) =>
            vm.servers = subitems @sd.store_servers(o),ip:""
            vm.lang = lang.central_store_list
        return [html, vm]
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0   
            (new CentralRecordDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    create_mysql: () =>
        (new CentralCreateStoreModal(@sd, this)).attach()
    
    combine: () =>
        selected_backup = $("#backup_option").val()
        selected_export = $("#export_option").val()
        selected_client = $("#client_option").val()
        if selected_backup is "no"
            @vm.action_tips = "请选择备份服务器"
            $('.alert-error', $('#submit_form')).show();
            return
        if selected_backup is selected_export
            @vm.action_tips = "备份服务器和主服务器地址需不相同"
            $('.alert-error', $('#submit_form')).show();
            return
        @frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).combine selected_export,selected_backup,selected_client
        #chain.chain @sd.update('all')
        show_chain_progress(chain).done (data)=>
            $("#myTab li:eq(2) a").tab "show"
            $("#myTab li:eq(1)").addClass "done"
            $('#form_wizard_1').find('.button-previous').show()
            $('.alert-error', $('#submit_form')).hide()
            @vm.next_action = "开启";
            (new MessageModal lang.central_combine.success).attach()
            #@attach()
        .fail =>
            (new MessageModal lang.central_combine.error).attach()
                
    expand: () =>
        sub = []
        for i in @vm.storages
            if i.checked
                sub.push i.ip
        sub = sub.join ","
        selected_export = $("#export_option").val()
        @frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).export selected_export,sub
        #chain.chain @sd.update('all')
        show_chain_progress(chain).done =>
            #@attach()
            #@vm.expand_success = true
            @vm.expand_result = "扩容成功"
            (new MessageModal(lang.central_modal.expand_success)).attach()
            
    start: () =>
        selected_client = $("#client_option").val()
        @frozen()
        chain = new Chain
        chain.chain =>
            (new MachineRest @sd.host).client selected_client
        chain.chain @sd.update("all")
        show_chain_progress(chain).done =>
            (new MessageModal (@vm.lang.start_success)).attach()
            @attach()
        
    mount: (ip,name) =>
        (new ConfirmModal @vm.lang.mount, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozoset name,ip,""
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.mount_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "storage",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
            
class CentralColonylistPage extends DetailTablePage
    constructor: (@sd,@switch_to_page) ->
        super "centralcolonylistpage-", "html/centralcolonylistpage.html"
        
        table_update_listener @sd.clouds, "#store-table", =>
            @vm.devices = @subitems()
            
        table_update_listener @sd.colonys, "#store-table", =>
            @vm.devices = @subitems()
            
        $(@sd).on 'CreateFilesystem', (e, event) =>
            if event.count is event.success
                (new MessageModal "扩容成功").attach()
            else
                msg = ""
                ip = ""
                for i in event.errorMsg
                    msg = msg  + i.msg + ";"
                    ip = ip  + i.ip + ";"
                (new MessageModal (lang.central_error.changeclient(ip,msg))).attach()
                
        $(@sd).on 'ClientChange', (e, event) =>
            if event.count is event.success
                (new MessageModal "修改客户端成功").attach()
            else
                ip = ""
                msg = ""
                for i in event.errorMsg
                    msg = msg  + i.msg + ";"
                    ip = ip  + i.ip + ";"
                (new MessageModal (lang.central_error.changeclient(ip,msg))).attach()

    define_vm: (vm) =>
        vm.devices = @subitems() 
        vm.lang = lang.central_colony_list
        vm.create_mysql = @create_mysql
        vm.check = @check
        vm.unset = @unset
        vm.pre = @pre
        vm.mount = @mount
        vm.rendered = @rendered
        vm.fattr_server_status = fattr.server_status
        vm.fattr_server_health = fattr.server_health
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.devices
                r.checked = vm.all_checked
        vm.delete_record = @delete_record
        vm.detail = @detail
        vm.expand = @expand
        vm.change_samba = @change_samba
        vm.stop = @stop
        vm.create = @create
        vm.start_manual = @start_manual
        vm.start_auto = @start_auto
        vm.switch_to_page = @switch_to_page
        vm.change_client = @change_client
        
    rendered: () =>
        super()
        console.log(99);
        $('.tip-twitter').remove();
        PortletDraggable.init()
        $('.tooltips').tooltip()
        @vm.devices = @subitems()
        @data_table = $("#store-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $('.hastip').poshytip(
            className: 'tip-twitter'
            showTimeout: 0
            alignTo: 'target',
            alignX: 'center',
            alignY: 'top',
            offsetY: 0,
            allowTipHover: false,
            fade: false
        )
        ###$('input').iCheck(
            checkboxClass: 'icheckbox_minimal',
            radioClass: 'iradio_minimal',
            increaseArea: '20%'
        )
        $('#all_checked').on 'ifChecked',(event) =>
            $('input').iCheck('check')
        $('#all_checked').on 'ifUnchecked', (event) =>
            $('input').iCheck('uncheck')###
        @nprocess()
    
    change_client:(uuid,name,store) =>
        ##if !store
            #return (new MessageModal("请先进行扩容操作")).attach()
        (new CentralColonyChangeClientModal(@sd, this, uuid,name)).attach()
            
    data_refresh: (status) =>
        try
            chain = new Chain
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                #@attach()
                if status
                    (new MessageModal "启动成功").attach()
                else
                    (new MessageModal "启动失败").attach()
        catch e
            return
            
    nprocess:() =>
        NProgress.start()
        setTimeout (=> NProgress.done();$('.fade').removeClass('out')),10
        
    subitems: () =>
        arrays = subitems @sd.colonys.items,cid:"",uuid:"", zoofs:false, store:false, created:"", \
                checked:false, detail_closed:true,device:""
        
        #console.log(@sd.colonys.items);
        ###arrays = [{"cid":"集群1","samba":"192.168.2.190","store":true,"zoofs":true,"checked":false,"detail_closed":true,id:"e7505a21221e"}, \
               {"name":"集群2","samba":"192.168.2.191","store":true,"zoofs":false,"checked":false,"detail_closed":true,id:"e7505a21221es"}]###
        arrays
        
    detail_html: (store) =>
        html = avalon_templ store.uuid, "html/colony_detail_row.html"
        for i in @sd.colonys.items
            if i.uuid is store.uuid
                o = i
        vm = avalon.define store.uuid, (vm) =>
            vm.colonys = subitems @sd.colony_list(o.device),ip:"",chinese_type:"",status:"",client:""
            vm.lang = lang.central_colony_list
            vm.fattr_server_health = fattr.server_health
        return [html, vm]
        
    change_samba:(colony_id) =>
        (new CentralChangeSambaModal(@sd, this, colony_id)).attach()
    
    _check_client:(uuid) =>
        for i in @sd.clouds.items
            if i.devtype is "client" and i.clusterid is uuid
                return false
        return true
        
    stop:(uuid) =>
        if !@_check_client(uuid)
            return (new MessageModal ('请先解除全部访问权限')).attach()
        (new ConfirmModal '初始化并不会删除集群记录，确认要初始化集群吗？', =>
            @frozen()
            chain = new Chain
            chain.chain =>
                query = (new MachineRest @sd.host).init_colony uuid
                query.done (data) =>
                    if data.status is "error"
                        (new MessageModal(lang.central_error.message(data.errcode,data.description))).attach()
                    else
                        (new MessageModal ('初始化成功')).attach()
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()
        
    delete_record:() =>
        deleted = ($.extend({},r.$model) for r in @vm.devices when r.checked)
        if deleted.length isnt 0
            for i in deleted
                if i.zoofs or i.store
                    return (new MessageModal ("请先停止集群")).attach()
            (new CentralColonyDeleteModal(@sd, this, deleted)).attach()
        else
            (new MessageModal(@vm.lang.delete_error)).attach()
            
    create: () =>
        (new CentralCreateColonyModal(@sd, this)).attach()
    
    start_auto:(dev,zoofs,store) =>
        tmp = []
        (tmp.push i.ip) for i in dev when i.devtype is "storage"
        dev = {"storage":tmp}
        if !zoofs
            return (new MessageModal("请先进行预配置")).attach()
        if store
            return (new MessageModal("该集群已扩容")).attach()
        (new CentralStartModal(@sd, this, dev)).attach()
        
    start_manual:(dev,zoofs,store) =>
        tmp = []
        (tmp.push i.ip) for i in dev when i.devtype is "storage"
        dev = {"storage":tmp}
        if !zoofs
            return (new MessageModal("请先进行预配置")).attach()
        if store
            return (new MessageModal("该集群已扩容")).attach()
        (new CentralProStartModal(@sd, this, dev)).attach()
        
    expand: (uuid,zoofs) =>
        if zoofs
            return (new MessageModal("该集群已预配置")).attach()
        #获取chain的detail
        (new ConfirmModal "确认要进行预配置吗？", =>
            @frozen()
            chain = new Chain
            chain.chain =>
                query = (new MachineRest @sd.host).expand_pro uuid
                query.done (data) =>
                    if data.status is "error"
                        (new MessageModal(lang.central_error.message(data.errcode,data.description))).attach()
                    else
                        (new MessageModal ('预配置成功')).attach()
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                @attach()
        ).attach()
        #(new CentralProExpandModal(@sd, this, uuid)).attach()
        
    mount: (ip,name) =>
        (new ConfirmModal @vm.lang.mount, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozoset name,ip,""
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.mount_success)).attach()
                @attach()
        ).attach()
        
    pre: () =>
        (new CentralPreModal(@sd, this)).attach()
    
    unset:(name, ip) =>
        (new ConfirmModal @vm.lang.stop, =>
            @frozen()
            chain = new Chain
            chain.chain =>
                (new MachineRest @sd.host).rozostop "storage",ip
            chain.chain @sd.update("all")
            show_chain_progress(chain).done =>
                (new MessageModal (@vm.lang.stop_success)).attach()
                @attach()
        ).attach()
        
    check: (ip, name) =>
        tmp = ['mysql','mongo','gateway','fileserver','web']
        if name in tmp 
            (new ConfirmModal lang.central_mysql.check, =>
                @frozen()
                chain = new Chain
                chain.chain =>
                    (new MachineRest @sd.host).check ip,name
                chain.chain @sd.update("all")
                show_chain_progress(chain).done =>
                    (new MessageModal (lang.central_mysql.check_success)).attach()
                    @attach()
            ).attach()
        else
            (new MessageModal (lang.central_mysql.check_error)).attach()
            
###########################  old  #########################
this.DetailTablePage = DetailTablePage
this.DiskPage = DiskPage
this.InitrPage = InitrPage
this.LoginPage = LoginPage
this.MaintainPage = MaintainPage
this.OverviewPage = OverviewPage
this.QuickModePage = QuickModePage
this.RaidPage = RaidPage
this.SettingPage = SettingPage
this.VolumePage = VolumePage
this.Page = Page

############################  cloud  #######################
this.CentralLoginPage = CentralLoginPage
this.CentralStoremonitorPage = CentralStoremonitorPage
this.CentralServermonitorPage = CentralServermonitorPage
this.CentralStoreDetailPage = CentralStoreDetailPage
this.CentralServerDetailPage = CentralServerDetailPage
this.CentralServerViewPage = CentralServerViewPage
this.CentralStoreViewPage = CentralStoreViewPage
this.CentralServerlistPage = CentralServerlistPage
this.CentralStorelistPage = CentralStorelistPage
this.CentralClientlistPage = CentralClientlistPage
this.CentralWarningPage = CentralWarningPage
this.CentralMonitorPage = CentralMonitorPage
this.CentralMachinelistPage = CentralMachinelistPage
this.CentralStartlistPage = CentralStartlistPage
this.CentralColonylistPage = CentralColonylistPage