class Rest
    constructor: (@host) ->
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data

    get: (url, data) =>
        @ajax "get", url, data

    _delete: (url, data) =>
        @ajax "delete", url, data

    post: (url, data) =>
        @ajax "post", url, data

    put: (url, data) =>
        @ajax "put", url, data

class ResRest extends Rest
    constructor: (@host, @res) ->
    list: () =>
        @get "/api/#{@res}"

    create: (params) =>
        @post "/api/#{@res}", params

    delete: (id) =>
        @_delete "/api/#{@res}/#{id}"

class DiskRest extends Rest
    list: () =>
        @get "/api/disks"

    format: (location) =>                 #格式化
        @put "/api/disks/#{location}", host: 'native'

    set_disk_role: (location, role, raidname) =>             #为磁盘设定角色
        data = role: role
        if raidname isnt null
            data.raid = raidname
        @put "/api/disks/#{location}", data

class RaidRest extends ResRest
    constructor: (host) ->
        super host, 'raids'

class VolumeRest extends ResRest
    constructor: (host) ->
        super host, 'volumes'

class InitiatorRest extends ResRest
    constructor: (host) ->
        super host, 'initiators'

    map: (wwn, volume) =>
        @post "/api/#{@res}/#{wwn}/luns", volume: volume

    unmap: (wwn, volume) =>
        @delete "#{wwn}/luns/#{volume}"

class DSURest extends Rest
    list: () =>
        @get "/api/dsus"
    
    slient: () =>
        @put "/api/beep"
        
class NetworkRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 6000

    list: () =>
        @get "/api/interfaces"
    
    config: (iface, ipaddr, netmask) =>
        @put "/api/network/interfaces/#{iface}", address:ipaddr, netmask:netmask

    create_eth_bonding: (ip, netmask, mode) =>
        @post "/api/network/bond/bond0",
            slaves: "eth0,eth1"
            address: ip
            netmask: netmask
            mode: mode

    modify_eth_bonding: (ip, netmask)=>
        @put "/api/network/bond/bond0", address: ip, netmask: netmask

    cancel_eth_bonding: =>
        @_delete "/api/network/bond/bond0"

class JournalRest extends Rest
    list: (offset, limit) =>
        @get "/api/journals"
    delete_log: () =>
        @post "/api/journalsdel"
    
    disk_info:(ip) =>
        @post "/api/cloudredisks",ip:ip
        
    raid_info:(ip) =>
        @post "/api/cloudreraids",ip:ip
        
class UserRest extends Rest
    change_password: (name, old_password, new_password) =>
        @put "/api/users/#{name}/password", old_password: old_password, new_password: new_password

class ZnvConfigRest extends Rest
    precreate: (volume) =>
        @post "/api/precreate", volume: volume
        
    znvconfig: (bool,serverid, local_serverip, local_serverport, cmssverip, cmssverport, directory) =>
        if bool
            @put "/api/zxconfig/store/set",serverid: serverid,local_serverip: local_serverip,local_serverport: local_serverport,cmssverip: cmssverip,cmssverport: cmssverport,directory: directory
        else
            @put "/api/zxconfig/dispath/set",serverid: serverid,local_serverip: local_serverip,local_serverport: local_serverport,cmssverip: cmssverip,cmssverport: cmssverport

    start_service: (bool) =>
        if bool
            @put "/api/zxconfig/store/start"
        else
            @put "/api/zxconfig/dispath/start"

    stop_service: (bool) =>
        if bool
            @put "/api/zxconfig/store/stop"
        else
            @put "/api/zxconfig/dispath/stop"


class CommandRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 4000

    poweroff: () =>
        @put "/api/commands/poweroff"

    reboot: () =>
        @put "/api/commands/reboot"

    sysinit: () =>
        @put "/api/commands/init"
        
    recover: () =>
        @put "/api/commands/recovery"        

    create_lw_files: () =>
        @put "/api/commands/create_lw_files", async: true

    slient: () =>
        @put "/api/beep"
        
class GatewayRest extends Rest
    query: () =>
        @get "/api/network/gateway"

    config: (address) =>
        @put "/api/network/gateway", address: address

class SystemInfoRest extends Rest
    query: () =>
        @get "/api/systeminfo"

class SessionRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 4000

    create: (name, passwd) =>
        @post "/api/sessions", name: name, password: passwd

class FileSystemRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 300 * 1000

    query: () =>
        @get "/api/filesystems"

    create_cy: (name, volume) =>
        @post "/api/filesystems", name:name, volume:volume
        
    create: (name, type, volume) =>
        @post "/api/filesystems", name:name, type:type, volume:volume
        
    delete: (name) =>
        @_delete "/api/filesystems/#{name}"

    scan: (name) =>
        @put "/api/filesystems/detection", name:name

class MonFSRest extends Rest
    query: () =>
        @get "/api/monfs"

    create: (name, volume) =>
        @post "/api/monfs", name:name, volume:volume

    delete: (name) =>
        @_delete "/api/monfs/#{name}"

class IfacesRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 2000
            
    query: () =>
        @get "/api/ifaces"


class SyncConfigRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            timeout: 400000

    sync_enable: (name) =>
        @put "/api/sync", name: name, command: "start"  
                                
    sync_disable: (name) =>
        @put "/api/sync", name: name, command: "stop"  
        
        
        
###########################
##更新使用PUT 插入使用POST##
###########################
class MachineRest extends Rest
    ajax: (type, url, data) =>
        $.ajax
            headers: Accept : "application/json"
            type: type
            url: "http://#{@host}#{url}"
            data: data
            #timeout: 6000
            
    query: () =>
        @get "/api/machines"
            
    monitor: (uuid, ip, slotnr,devtype,role) =>
        @post "/api/machines", uuid:uuid, ip:ip, slotnr:slotnr,devtype:devtype,role:role
     
    unmonitor:(uuid) =>
        @_delete "/api/machines/#{uuid}"
        
    machine: (uuid) =>
        @get "/api/machine/#{uuid}"
        
    add:(ip,type) =>
        @post "/api/devices", ip:ip , version:"ZS2000", devtype:type, size:"4U"

    delete_record:(uuid) =>
        @_delete "/api/devices/#{uuid}"
        
    rozostop: (name, ip) =>
        @post "/api/rozostop", stoptype:name, ip:ip
        
    export: (ip, expand) =>
        @post "/api/export", ip:ip, expand:expand
        
    storage: (ip, cid) =>
        @post "/api/storage", export:ip, cid:cid
        
    download_log: (ip) =>
        @get "/api/diagnosis/#{ip}"
      
    refresh_detail:(uid) =>
        @post "/api/machinedetails",uuid:uid

    get_card:() =>
        @get "/api/getMsg"
       
    combine: (master_ip,backup_ip,vip_ip) =>
        @post "/api/safety",master:master_ip ,backup:backup_ip ,vip:vip_ip
        
    create_colony: (_export,_storage,_client,_name) =>
        #@post "/api/cluster",export:_export ,storage:_storage,client:_client ,cluster:_name
        @post "/api/cluster",export:_export ,storage:_storage ,cluster:_name
        
    expand_pro: (uuid) =>
        @post "/api/zoofs",uuid:uuid,level:0
        
    prostart:(arrays) =>
        @post "/api/storage",rest:arrays
        
    delete_client:(uuid) =>
        @_delete "/api/client/#{uuid}"
        
    handle_log_pro:(uid) =>
        @put "/api/emergency/#{uid}"
        
        
    add_email:(address,level,ttl) =>
        @post "/api/mail",address:address ,level:level ,ttl:ttl
        
    change_email:(uid,level,ttl) =>
        @put "/api/mail/#{uid}",level:level ,ttl:ttl
        
    del_email:(uid) =>
        @_delete "/api/mail/#{uid}"
        
    change_value:(uid,normal,bad) =>
        @put "/api/threshhold/#{uid}", normal:normal, warning:bad
        
    handle_log: (uid) =>
        @post "/api/attention", uid:uid
        
    open_capture: () =>
        @post "/api/ansible",active:true
        
    close_capture: () =>
        @post "/api/ansible",active:false
    
    unmonitor_pro:(uuid) =>
        @_delete "/api/machines/#{uuid}"
        
    change_client:(uuid,ip) =>
        @post "/api/ansible",active:false
        
    init_colony:(uuid) =>
        @_delete "/api/zoofs/#{uuid}"
    
    delete_colony:(uuid) =>
        @_delete "/api/cluster/#{uuid}"
        
    client: (cid,clients) =>
        @post "/api/client", clients:clients,cid:cid
        
class CenterRest extends ResRest
    constructor: (host) ->
        super host, 'machines'
        
class CloudRest extends ResRest
    constructor: (host) ->
        super host, 'devices'
        
class MachineDetailRest extends ResRest
    constructor: (host) ->
        super host, 'machinedetails'

class StoreRest extends ResRest
    constructor: (host) ->
        super host, 'storeviews'
        
class WarningRest extends ResRest
    constructor: (host) ->
        super host, 'threshhold'
        
class EmailRest extends ResRest
    constructor: (host) ->
        super host, 'mail'
        
class ColonyRest extends ResRest
    constructor: (host) ->
        super host, 'cluster'
        
this.ColonyRest = ColonyRest
this.MachineDetailRest = MachineDetailRest
this.EmailRest = EmailRest
this.WarningRest = WarningRest
this.CenterRest = CenterRest
this.CloudRest = CloudRest
this.StoreRest = StoreRest
this.DSURest = DSURest
this.DiskRest = DiskRest
this.RaidRest = RaidRest
this.VolumeRest = VolumeRest
this.InitiatorRest = InitiatorRest
this.UserRest = UserRest
this.NetworkRest =  NetworkRest
this.JournalRest = JournalRest
this.CommandRest = CommandRest
this.GatewayRest = GatewayRest
this.SystemInfoRest = SystemInfoRest
this.SessionRest = SessionRest
this.MachineRest = MachineRest
this.MonFSRest = MonFSRest
this.IfacesRest = IfacesRest
this.FileSystemRest = FileSystemRest
this.ZnvConfigRest = ZnvConfigRest
this.SyncConfigRest = SyncConfigRest