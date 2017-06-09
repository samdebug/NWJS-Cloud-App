class Modal extends AvalonTemplUI
    constructor: (@prefix, @src, @attr={}) ->
        $.extend(@attr, class: "modal fade")
        super @prefix, @src, "body", false, @attr

    attach: () =>
        $("body").modalmanager "loading"
        super()

    rendered: () =>
        super()
        $div = $("##{@id}")
        $div.on "hide", (e) =>
            if e.currentTarget == e.target
                setTimeout (=> @detach()), 1000
        $div.modal({backdrop:"static"})
        $(".tooltips").tooltip()

    hide: () =>
        $("##{@id}").modal("hide")

class ServerUI extends Modal
    constructor: (@serverUI=server_type) ->
        super "confirm-", 'html/serverui.html',\
        style: "max-width:400px;left:60%;text-align:center"
        
    define_vm: (vm) =>
        vm.lang = lang.server
        vm.central = @central
        vm.store = @store
   
    rendered: () =>
        super()
        @backstretch = $(".login").backstretch([
            "images/login-bg/4a.jpg",
            ], fade: 1000, duration: 5000).data "backstretch"

    store: () =>
        @serverUI.type = 'store'
        window.adminview = new AdminView(@serverUI)
        avalon.scan()
        App.init()
        
    central: () =>
        @serverUI.type = 'central'
        @serverUI.store = false
        window.adminview = new CentralView(@serverUI)
        avalon.scan()
        App.init()    

class MessageModal extends Modal
    constructor: (@message, @callback=null) ->
        super "message-", "html/message_modal.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.message_modal
        vm.callback = => @callback?()

class MessageModal_reboot extends Modal
    constructor: (@message,@bottom,@dview,@sd,@settings) ->
        super "message-", "html/message_modal_reboot.html"
        
    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.message_modal
        vm.recovered = @bottom
        vm.reboot = @reboot

    reboot: () =>
        chain = new Chain()
        chain.chain => (new CommandRest(@dview.sd.host)).reboot()
        @hide()
        show_chain_progress(chain, true).fail =>
            @settings.removeLoginedMachine @dview.host
            @sd.close_socket()
            arr_remove sds, @sd
            setTimeout(@dview.switch_to_login_page, 2000)

class CentralSearchModal extends Modal
    constructor: (@sd, @page, @machines, @type) ->
        console.log @page
        super "central-search-modal-", "html/central_search_modal.html"
        
    define_vm: (vm) =>
        vm.machines = @subitems()
        vm.lang = lang.central_search_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.machines
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.machines").validate(
            valid_opt(
                rules:
                    'machine-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'machine-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.machines").validate().form()
            selecteds = []
            for i in @vm.machines when i.checked
                selecteds.push i
            @monitoring selecteds
            
    monitoring: (devices) =>
        chain = new Chain
        for device in devices
            uuid = device.uuid + device.ifaces[0].split('.').join('')
            chain.chain @_eachMonitor(uuid, device.ifaces[0])
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done (data)=>
            (new MessageModal lang.central_search_modal.monitor_success).attach()
            #@tips(devices)
            @page.attach()
        .fail =>
            (new MessageModal lang.central_search_modal.monitor_error).attach()

    _eachMonitor: (uuid, ip, slotnr=24) =>
        return ()=> (new MachineRest(@sd.host) ).monitor uuid, ip, slotnr, @type
    
    tips:(devices) =>
        try
            info = []
            datas = {}
            for i in devices
                info.push i.ifaces[0]
                datas[i.ifaces[0]] = 0
            ((datas[j.ip] = datas[j.ip] + 1 )for j in @sd.stores.items.journals when j.ip in info)
            for k in info
                if datas[k] > 0
                    if @type is "storage"
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
        
    subitems: () =>
        items = subitems @machines, uuid:"", ifaces:"", Slotnr:24,\
             checked:false
        return items
             
class CentralRecordDeleteModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()
        
    submit: () =>
        query = @message
        @page.frozen()
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in query
            chain.chain ->
                (rest.delete_record query[i].uuid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(@vm.lang.delete_success)).attach()
            
class CentralColonyDeleteModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()
        
    submit: () =>
        query = @message
        @page.frozen()
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in query
            chain.chain ->
                (rest.delete_colony query[i].uuid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(@vm.lang.delete_success)).attach()
            
class CentralEmailDeleteModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()

    submit: () =>
        query = @message
        @page.frozen()
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in query
            chain.chain ->
                (rest.del_email query[i].uid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(@vm.lang.delete_success)).attach()
        
class CentralServerCpuModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-cpu-modal-", "html/central_server_cpu_modal.html"
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.cpu = @subitems()
                
    define_vm: (vm) =>
        vm.lang = lang.central_server_cpu_modal
        vm.submit = @submit
        vm.cpu = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#cpu-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total' and i.cpu isnt 0
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
            
class CentralServerCacheModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-cache-modal-", "html/central_server_cache_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_server_cache_modal
        vm.submit = @submit
        vm.cache = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#cache-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total'
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
            
class CentralServerMemModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-mem-modal-", "html/central_server_mem_modal.html"
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.mem = @subitems()
    define_vm: (vm) =>
        vm.lang = lang.central_server_mem_modal
        vm.submit = @submit
        vm.mem = @subitems()
        vm.rendered = @rendered
    rendered: () =>
        super()
        @data_table = $("#mem-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
    subitems: () =>
        items = @sd.stats.items
        latest = items[items.length-1]
        tmp = []
        try
            for i in latest.master.process
                if i.protype isnt 'total' and i.mem isnt 0
                    tmp.push i
            return tmp
        catch error
            return tmp
    submit: () =>
        @hide()
        
class CentralStoreDetailModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-store-detail-modal-", "html/central_store_detail_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_store_detail_modal
        vm.submit = @submit
        vm.disks = @subitems_disks()
        vm.raids = @subitems_raids()
        vm.volumes = @subitems_volumes()
        vm.filesystems = @subitems_filesystems()
        vm.initiators = @subitems_initiators()
        
        vm.rendered = @rendered
        
    rendered: () =>
        super()
        @data_table = $("#volume-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
            
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
    subitems: () =>
        temp = []
        for i in @message
            temp.push i
        return temp
        
    submit: () =>
        @hide()
        
class CentralPieModal extends Modal
    constructor: (@sd, @page, @type, @total, @used) ->
        super "central-pie-modal-", "html/central_pie_modal.html"
        @refresh_pie()
        
    define_vm: (vm) =>
        vm.lang = lang.central_pie_modal
        vm.submit = @submit
        vm.rendered = @rendered
        vm.type = @type
        
    rendered: () =>
        super()
        @refresh_pie()
    subitems: () =>
        return
        
    refresh_pie: () =>
        try
            if @type is '已用容量'
                datas_used = @get_used()
                @plot_pie datas_used,@type
            else
                @type = '总容量'
                datas_total = @get_cap()
                @plot_pie datas_total,@type
        catch error
            console.log error
            
    get_used: () =>
        data_used = {}
        datas_used = []
        machine_used = []
        
        for i in @sd.stores.items.Raid
            if i.MachineId not in machine_used
                machine_used.push i.MachineId
                
        for i in @sd.stores.items.Raid
            data_used[i.MachineId] = 0
            
        for i in @sd.stores.items.Raid
            data_used[i.MachineId] = data_used[i.MachineId] + i.Used
            
        for i in machine_used
            datas_used.push {name:i,y:data_used[i]/@used*100}
            
        for i in datas_used
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip 
        datas_used
        
    get_cap: () =>
        data_total = {}
        datas_total = []
        machine_total = []
        for i in @sd.stores.items.Disk
            if i.MachineId not in machine_total
                machine_total.push i.MachineId
                
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = 0
           
        for i in @sd.stores.items.Disk
            data_total[i.MachineId] = data_total[i.MachineId] + i.CapSector/2/1024/1024
            
        for i in machine_total
            datas_total.push {name:i,y:data_total[i]/@total*100}
            
        for i in datas_total
            for j in @sd.centers.items
                if i['name'] is j.Uuid
                    i['name'] = j.Ip 
        datas_total
        
    plot_pie: (datas, type) =>
        Highcharts.setOptions(
            lang:
                contextButtonTitle:"图表导出菜单"
                decimalPoint:"."
                downloadJPEG:"下载JPEG图片"
                downloadPDF:"下载PDF文件"
                downloadPNG:"下载PNG文件"
                downloadSVG:"下载SVG文件"
                printChart:"打印图表")
        
        $('#pie_charts').highcharts(
                chart: 
                    type: 'pie'
                    options3d:
                        enabled: true
                        alpha: 45
                        beta: 0
                    marginBottom:70
                title: 
                    text: type
                    align:'center'
                    verticalAlign: 'top'
                    style:
                        fontWeight:'bold'
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
                        depth: 35
                        slicedOffset: 15
                        showInLegend: true
                        dataLabels: 
                            enabled: true
                            format: '{point.percentage:.1f} %'
                            style: 
                                fontSize:'14px'
                        point:
                            events:
                                legendItemClick: () ->return false
                legend:
                    backgroundColor: '#FFFFFF'
                    layout: 'vertical'
                    floating: true
                    align: 'center'
                    verticalAlign: 'bottom'
                    itemMarginBottom: 5
                    x: 0
                    y: 20
                    labelFormatter: () ->
                        return @name
                series: [
                    type: 'pie'
                    name: ''
                    data: datas
                ])
                
    submit: () =>
        @hide()
        
class ConfirmModal_unlink extends Modal
    constructor: (@message, @confirm, @cancel,@warn) ->
        super "confirm-", "html/confirm_Initr.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.warn = lang.initr_unlink_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()
        
class ConfirmModal_link extends Modal
    constructor: (@message, @confirm, @cancel,@warn) ->
        super "confirm-", "html/confirm_Initr.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.warn = lang.initr_link_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()
            
class ConfirmModal extends Modal
    constructor: (@message, @confirm, @cancel) ->
        super "confirm-", "html/confirm_modal.html"

    define_vm: (vm) =>
        vm.message = @message
        vm.lang = lang.confirm_modal
        vm.submit_confirm = => @confirm?()
        vm.cancel = => @cancel?()


class ConfirmModal_more extends Modal
    constructor: (@title,@message,@sd,@dview,@settings) ->
        super "confirm-", "html/confirm_vaildate_modal.html"
        @settings = new SettingsManager
    define_vm: (vm) =>
        vm.title = @title
        vm.message = @message
        vm.lang = lang.confirm_vaildate_modal
        vm.confirm = true
        vm.confirm_passwd = ""
        vm.submit = @submit
        vm.bottom = true
        vm.sysinit = @sysinit
        vm.recover = @recover
        vm.keypress_passwd = @keypress_passwd
        
    rendered: () =>
        super()
        $.validator.addMethod("same", (val, element) =>
            if @vm.confirm_passwd != 'passwd'
                return false
            else
                return true
        , "密码输入错误")

        $("form.passwd").validate(
            valid_opt(
                rules:
                    confirm_passwd:
                        required: true
                        maxlength: 32
                        same: true
                messages:
                    confirm_passwd:
                        required: "请输入正确的确认密码"
                        maxlength: "密码长度不能超过32个字符"))

    submit: () =>
        if @title == @vm.lang.btn_sysinit
            @sysinit()
        else if @title == @vm.lang.btn_recover
            @recover()

    keypress_passwd: (e) =>
        @submit() if e.which is 13    

    sysinit: () =>
        if $("form.passwd").validate().form()
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).sysinit()
            @hide()
            show_chain_progress(chain, true).fail (data)=>
                @settings.removeLoginedMachine @dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                setTimeout(@dview.switch_to_login_page, 2000)
             
    recover: () =>
        if $("form.passwd").validate().form()
            chain = new Chain()
            chain.chain => (new CommandRest(@dview.sd.host)).recover()
            @hide()
            show_chain_progress(chain, true).done (data)=>
                (new MessageModal_reboot(lang.maintainpage.finish_recover,@vm.bottom,@dview,@sd,@settings)).attach()
            .fail (data)=>
                console.log "error"
                console.log data
                
class ConfirmModal_scan extends Modal
    constructor: (@sd, @page, @title, @message, @fs) ->
        super "confirm-", "html/confirm_reboot_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.confirm_reboot_modal
        vm.title = @title
        vm.message = @message
        vm.submit = @reboot
        vm.res = @fs

    reboot: () =>
        chain = new Chain()
        chain.chain => (new CommandRest(@sd.host)).reboot()
        @hide()
        show_chain_progress(chain, true).fail =>
            @sd.close_socket()
            arr_remove sds, @sd      
            
class ResDeleteModal extends Modal
    constructor: (prefix, @page, @res, @lang) ->
        super prefix, 'html/res_delete_modal.html'

    define_vm: (vm) =>
        vm.lang = @lang
        vm.res = @res
        vm.submit = @submit

    rendered: () =>
        $(".chosen").chosen()
        super()

    submit: () =>
        chain = @_submit($(opt).prop "value" for opt in $(".modal-body :selected"))
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class SyncDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "sync-delete-", page, res, lang.confirm_sync_modal
        
    _submit: (real_failed_volumes) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(real_failed_volumes, (v) => (=> (new SyncConfigRest(@sd.host)).sync_disable v)))
            .chain @sd.update("volumes")
        return chain
            
class RaidDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "raid-delete-", page, res, lang.raid_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (r) => (=> (new RaidRest(@sd.host)).delete r)))
            .chain @sd.update("raids")
        return chain

class RaidCreateDSUUI extends AvalonTemplUI
    constructor: (@sd, parent_selector, @enabled=['data','spare'], @on_quickmode=false) ->
        super "dsuui-", "html/raid_create_dsu_ui.html", parent_selector
        for dsu in @vm.data_dsus
            @watch_dsu_checked dsu

    define_vm: (vm) =>
        vm.lang = lang.dsuui
        vm.data_dsus = @_gen_dsus "data"
        vm.spare_dsus = @_gen_dsus "spare"
        vm.active_index = 0
        vm.on_quickmode = @on_quickmode
        vm.disk_checkbox_click = @disk_checkbox_click
        vm.dsu_checkbox_click = @dsu_checkbox_click
        vm.data_enabled  = 'data' in @enabled
        vm.spare_enabled = 'spare' in @enabled
        vm.disk_list = @disk_list
        vm.totals = @totals()
        
    totals:()=>
        
        tmp = [{"ip":"192.168.2.141"},{"ip":"192.168.2.142"},{"ip":"192.168.2.143"},{"ip":"192.168.2.144"}]
        tmp
        
    dsu_checkbox_click: (e) =>
        e.stopPropagation()
        
    disk_list: (disks)=>
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)
        
    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', 'kicked':'损坏'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length > 0
                        status += '阵列: ' + val + '<br/>'
                    else
                        status += '阵列: 无'
        return status
        
    active_tab: (dsu_location) =>
        for dsu, i in @vm.data_dsus
            if dsu.location is dsu_location
                @vm.active_index = i

    disk_checkbox_click: (e) =>
        e.stopPropagation()
        location = $(e.target).data "location"
        if location
            dsutype = $(e.target).data "dsutype"
            [dsus, opp_dsus] = if dsutype is "data"\
                then [@vm.data_dsus, @vm.spare_dsus]\
                else [@vm.spare_dsus, @vm.data_dsus]
            dsu = @_find_dsu dsus, location
            opp_dsu = @_find_dsu opp_dsus, location
            @_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            @_count_dsu_checked_disks opp_dsu

           ### if dsutype is "data"
                @_calculatechunk dsu
            else
                @_calculatechunk opp_dsu
            $("#dsuui").change()       ###

    watch_dsu_checked: (dsu) =>
        dsu.$watch 'checked', () =>
            for col in dsu.disks
                for disk in col
                    if not disk.avail
                        continue
                    disk.checked = dsu.checked
            opp_dsu = @_get_opp_dsu dsu
            @_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            @_count_dsu_checked_disks opp_dsu

           # @_calculatechunk dsu
            #$("#dsuui").change()

    _calculatechunk: (dsu) =>
        @_count_dsu_checked_disks dsu
        nr = dsu.count
        if nr <= 0
            return "64KB"
        else if nr == 1
            return "256KB"
        else
            ck = 512 / (nr - 1)
            if ck > 16 and ck <= 32
                return "32KB"
            else if ck > 32 and ck <= 64
                return "64KB"
            else if ck > 64 and ck <= 128
                return "128KB"
            else if ck > 128
                return "256KB"

    getchunk:() =>
        chunk_value = []
        for dsu in @vm.data_dsus
            chunk_value.push  @_calculatechunk(dsu)
        return chunk_value[0]

    _count_dsu_checked_disks: (dsu) =>
        count = 0
        for col in dsu.disks
            for disk in col
                if disk.checked
                    count += 1
        dsu.count = count

    _uncheck_opp_dsu_disks: (dsu, opp_dsu) =>
        for col in dsu.disks
            for disk in col
                if disk.checked
                    opp_disk = @_find_disk [opp_dsu], disk.$model.location
                    opp_disk.checked = false

    get_disks: (type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        @_collect_checked_disks dsus

    _collect_checked_disks: (dsus) =>
        disks = []
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    disks.push(disk.location) if disk.checked
        return disks

    check_disks: (disks, type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        disks = if $.isArray(disks) then disks else [disks]
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    for checked in disks
                        if disk.location is checked.location
                            disk.checked = true
        for dsu in dsus
            @_count_dsu_checked_disks dsu

    _find_disk: (dsus, location) =>
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    if disk.$model.location is location
                        return disk

    _find_dsu: (dsus, location) =>
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    if disk.$model.location is location
                        return dsu

    _get_opp_dsu: (dsu) =>
        opp_dsus = if dsu.data then @vm.spare_dsus else @vm.data_dsus
        for opp_dsu in opp_dsus
            if opp_dsu.location is dsu.location
                return opp_dsu

    _tabid: (tabid_prefix, dsu) =>
        "#{tabid_prefix}_#{dsu.location.replace('.', '_')}"

    _gen_dsus: (prefix) =>
        return ({location: dsu.location, tabid: @_tabid(prefix, dsu), checked: false,\
            disks: @_gen_dsu_disks(dsu), count: 0, data: prefix is 'data'} for dsu in @sd.dsus.items)

    _belong_to_dsu: (disk, dsu) =>
        disk.location.indexOf(dsu.location) is 0

    _update_disk_status: (location, dsu) =>
        for disk in @sd.disks.items
            if disk.location is location and @_belong_to_dsu(disk, dsu) and disk.raid is "" and disk.health isnt "failed" and disk.role is "unused"
                return true
        return false
    
    _update_disk_info: (location, dsu) =>
        info = []
        for disk in @sd.disks.items
            if disk.location is location and @_belong_to_dsu(disk, dsu)
                info = health:disk.health, cap_sector:disk.cap_sector, role:disk.role, raid:disk.raid
                return info
        
        'none'
        
    _gen_dsu_disks: (dsu) =>
        disks = []

        for i in [1..4]
            cols = []
            for j in [0...dsu.support_disk_nr/4]
                location = "#{dsu.location}.#{j*4+i}"
                o = location: location, avail: false, checked: false, offline: false, info: ""
                o.avail = @_update_disk_status(location, dsu)
                o.info = @_update_disk_info(location, dsu)
                cols.push o
            disks.push cols

        return disks

    rendered: () =>
        super()

class RaidSetDiskRoleModal extends Modal
    constructor: (@sd, @page) ->
        super "raid-set-disk-role-modal-",\
            "html/raid_set_disk_role_modal.html",\
            style: "min-width:670px;"
        @raid = null

    define_vm: (vm) =>
        vm.lang = lang.raid_set_disk_role_modal
        vm.raid_options = subitems @sd.raids.items, name:""
        vm.role = "global_spare"
        vm.submit = @submit
        vm.select_visible = false

        vm.$watch "role", =>
            vm.select_visible = if vm.role == "global_spare" then false else true

    rendered: () =>
        super()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui", ['spare'])
        @dsuui.attach()
        @add_child @dsuui
        $("input:radio").uniform()
        $("#raid-select").chosen()

        $.validator.addMethod("min-spare-disks", (val, element) =>
            nr = @dsuui.get_disks("spare").length
            return if nr is 0 then false else true)

        $("form.raid").validate(
            valid_opt(
                rules:
                    "spare-disks-checkbox":
                        "min-spare-disks": true
                messages:
                    "spare-disks-checkbox":
                        "min-spare-disks": "至少需要1块热备盘"))

    submit: () =>
        raid = null
        if @vm.select_visible
            chosen = $("#raid-select")
            raid = chosen.val()
        @set_disk_role @dsuui.get_disks("spare"), @vm.role, raid

    set_disk_role: (disks, role, raid) =>
        chain = new Chain
        for disk in disks
            chain.chain @_each_set_disk_role(disk, role, raid)
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    _each_set_disk_role: (disk, role, raid) =>
        return () => (new DiskRest @sd.host).set_disk_role disk, role, raid

class RaidCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "raid-create-modal-", "html/raid_create_modal.html", style: "min-width:670px;"

    define_vm: (vm) =>
        vm.lang = lang.raid_create_modal
        vm.name = ""
        vm.level = "5"
        #vm.chunk = "64KB"
        vm.rebuild_priority = "low"
        vm.sync = false
        vm.submit = @submit

    rendered: () =>
        super()
        @dsuui = new RaidCreateDSUUI(@sd, "#dsuui")
        @dsuui.attach()
        @add_child @dsuui
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        $("#sync").change =>
            @vm.sync = $("#sync").prop "checked"

        dsu = @prefer_dsu_location()
        [raids...] = (disk for disk in @sd.disks.items\
                                when disk.role is 'unused'\
                                and disk.location.indexOf(dsu) is 0)
        [cap_sector...] = (raid.cap_sector for raid in raids)
        total = []
        cap_sector.sort()
        for i in [0...cap_sector.length]
            count = 0
            for j in [0...cap_sector.length]
                if cap_sector[i] is cap_sector[j]
                    count++
            total.push([cap_sector[i],count])
            i+=count
            
        for k in [0...total.length]
            if total[k][1] >= 3
                [Raids...] = (disk for disk in raids\
                                when disk.cap_sector is total[k][0])
                for s in [0...3]
                    @dsuui.check_disks Raids[s]
                    @dsuui.active_tab dsu
                #@dsuui.check_disks Raids[3], "spare"
                break
                
        $.validator.addMethod("min-raid-disks", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return false
            else if level is 0 and nr < 1
                return false
            else if level is 1 and nr isnt 2
                return false
            else if level is 10 and nr%2 != 0  and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return "级别5阵列最少需要3块磁盘"
            else if level is 0 and nr < 1
                return "级别0阵列最少需要1块磁盘"
            else if level is 1 and nr != 2
                return "级别1阵列仅支持2块磁盘"
            else if level is 10 and nr%2 != 0 and nr > 0
                return "级别10阵列数据盘必须是偶数个"
        )
        $.validator.addMethod("spare-disks-support", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return false
            else if level is 10 and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return '级别0阵列不支持热备盘'
            else if level is 10 and nr > 0
                return '级别10阵列不支持热备盘'
        )
        $.validator.addMethod("min-cap-spare-disks", (val, element) =>
            level = parseInt @vm.level
            if level != 5
                return true
            map = {}
            for disk in @sd.disks.items
                map[disk.location] = disk

            spare_disks = (map[loc] for loc in @dsuui.get_disks("spare"))
            data_disks = (map[loc] for loc in @dsuui.get_disks())
            min_cap = Math.min.apply(null, (d.cap_sector for d in data_disks))
            for s in spare_disks
                if s.cap_sector < min_cap
                    return false
            return true
        , "热备盘容量太小"
        )
        
        $("form.raid").validate(
            valid_opt(
                rules:
                    name:
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.raids.items
                        maxlength: 64
                    "raid-disks-checkbox":
                        "min-raid-disks": true
                        maxlength: 24
                    "spare-disks-checkbox":
                        "spare-disks-support": true
                        "min-cap-spare-disks": true
                messages:
                    name:
                        required: "请输入阵列名称"
                        duplicated: "阵列名称已存在"
                        maxlength: "阵列名称长度不能超过64个字母"
                    "raid-disks-checkbox":
                        maxlength: "阵列最多支持24个磁盘"))

    submit: () =>
        if $("form.raid").validate().form()
            @create(@vm.name, @vm.level, @dsuui.getchunk(), @dsuui.get_disks(),\
                @dsuui.get_disks("spare"), @vm.rebuild_priority, @vm.sync)

    create: (name, level, chunk, raid_disks, spare_disks, rebuild, sync) =>
        @page.frozen()
        raid_disks = raid_disks.join ","
        spare_disks = spare_disks.join ","
        chain = new Chain
        chain.chain(=> (new RaidRest(@sd.host)).create(name: name, level: level,\
            chunk: chunk, raid_disks: raid_disks, spare_disks:spare_disks,\
            rebuild_priority:rebuild, sync:sync, cache:''))
            .chain @sd.update("raids")

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    count_dsu_disks: (dsu) =>
        return (disk for disk in @sd.disks.items\
                         when disk.role is 'unused'\
                         and disk.location.indexOf(dsu.location) is 0).length

    prefer_dsu_location: () =>
        for dsu in @sd.dsus.items
            if @count_dsu_disks(dsu) >= 3 
                return dsu.location
        return if @sd.dsus.length then @sd.dsus.items[0].location else '_'

class VolumeDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "volume-delete-", page, res, lang.volume_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (v) => (=> (new VolumeRest(@sd.host)).delete v)))
            .chain @sd.update('volumes')
        return chain

class VolumeCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "volume-create-modal-", "html/volume_create_modal.html"

    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        vm.lang = lang.volume_create_modal
        vm.volume_name = ""
        vm.raid_options = @raid_options()
        vm.raid = $.extend {}, @sd.raids.items[0]
        vm.fattr_cap_usage = fattr.cap_usage
        vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
        vm.unit = "GB"
        vm.automap = false
        vm.initr_wwn = ""
        vm.submit = @submit

        vm.$watch "raid",=>
            if vm.unit == "MB"
                vm.cap = sector_to_mb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else if vm.unit =="GB"
                vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else
                vm.cap = sector_to_tb(vm.raid.cap_sector-vm.raid.used_cap_sector)
        vm.$watch "unit",=>
            if vm.unit == "MB"
                vm.cap = sector_to_mb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else if vm.unit =="GB"
                vm.cap = sector_to_gb(vm.raid.cap_sector-vm.raid.used_cap_sector)
            else
                vm.cap = sector_to_tb(vm.raid.cap_sector-vm.raid.used_cap_sector)

        vm.$watch "volume_name", =>
            vm.initr_wwn = "#{prefix_wwn}:#{vm.volume_name}"

    rendered: () =>
        super()
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        $("#raid-select").chosen()
        $("#automap").change =>
            @vm.automap = $("#automap").prop "checked"
        chosen = $("#raid-select")
        chosen.change =>
            @vm.raid = $.extend {}, @sd.raids.get(chosen.val())
            $("form.volume").validate().element $("#cap")

        $.validator.addMethod("capacity", (val, elem) =>
            free_cap = @vm.raid.cap_sector - @vm.raid.used_cap_sector
            alloc_cap = cap_to_sector @vm.cap, @vm.unit
            if alloc_cap < mb_to_sector(1024)
                return false
            else if alloc_cap > free_cap
                return false
            else
                return true
        ,(params, elem) =>
            free_cap = @vm.raid.cap_sector - @vm.raid.used_cap_sector
            alloc_cap = cap_to_sector @vm.cap, @vm.unit
            if alloc_cap < mb_to_sector(1024)
                return "虚拟磁盘最小容量必须大于等于1024MB"
            else if alloc_cap > free_cap
                return "分配容量大于阵列的剩余容量"
        )
        
        $("form.volume").validate(
            valid_opt(
                rules:
                    name:
                        required: true
                        regex: '^[_a-zA-Z][-_a-zA-Z0-9]*$'
                        duplicated: @sd.volumes.items
                        maxlength: 64
                    capacity:
                        required: true
                        regex: "^\\d+(\.\\d+)?$"
                        capacity: true
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)+[_a-zA-Z0-9]*$'
                        maxlength: 96  
                messages:
                    name:
                        required: "请输入虚拟磁盘名称"
                        duplicated: "虚拟磁盘名称已存在"
                        maxlength: "虚拟磁盘名称长度不能超过64个字母"
                    capacity:
                        required: "请输入虚拟磁盘容量"
                    wwn:
                        required: "请输入客户端名称"
                        maxlength: "客户端名称长度不能超过96个字母"))

    raid_options: () =>
        raids_availble = []
        raids = subitems @sd.raids.items, id:"", name:"", health: "normal"
        for i in raids
            if i.health == "normal"
                raids_availble.push i
        return raids_availble
        
    submit: () =>
        if $("form.volume").validate().form()
            @create(@vm.volume_name, @vm.raid.name, "#{@vm.cap}#{@vm.unit}", @vm.automap, @vm.initr_wwn)
            if @_settings.sync
                @sync(@vm.volume_name)

    create: (name, raid, cap, automap, wwn) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new VolumeRest(@sd.host)).create name: name, raid: raid, capacity: cap
        if automap
            if not @sd.initrs.get wwn
                for n in @sd.networks.items
                    if n.link and n.ipaddr isnt ""
                        portals = n.iface
                        break
                chain.chain => (new InitiatorRest(@sd.host)).create wwn:wwn, portals:portals
            chain.chain => (new InitiatorRest(@sd.host)).map wwn, name
        chain.chain @sd.update('volumes')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    sync: (name) =>
        @page.frozen()
        chain = new Chain()
        chain.chain => 
            (new SyncConfigRest(@sd.host)).sync_enable(name)
            
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class InitrDeleteModal extends ResDeleteModal
    constructor: (@sd, page, res) ->
        super "initr-delete-", page, res, lang.initr_delete_modal

    _submit: (deleted) =>
        @page.frozen()
        chain = new Chain
        chain.chain($.map(deleted, (v) => (=> (new InitiatorRest(@sd.host)).delete v)))
        chain.chain @sd.update('initrs')
        return chain

class InitrCreateModal extends Modal
    constructor: (@sd, @page) ->
        super "initr-create-modal-", "html/initr_create_modal.html"
        @vm.show_iscsi = if @_iscsi.iScSiAvalable() and !@_settings.fc then true else false
        
    define_vm: (vm) =>
        @_settings = new (require("settings").Settings)
        @_iscsi = new IScSiManager
        vm.portals = @subitems()
        vm.lang = lang.initr_create_modal
        vm.initr_wwn = @_genwwn()
        vm.initr_wwpn = @_genwwpn()
        vm.show_iscsi = @show_iscsi
        
        vm.submit = @submit

        $(@sd.networks.items).on "updated", (e, source) =>
            @vm.portals = @subitems()

    subitems: () =>
        items = subitems @sd.networks.items,id:"",ipaddr:"",iface:"",netmask:"",type:"",checked:false
        removable = []
        if not @_able_bonding()
            for eth in items
                removable.push eth if eth.type isnt "bond-slave"
            return removable
        items

    _able_bonding: =>
        for eth in @sd.networks.items
            return false if (eth.type.indexOf "bond") isnt -1
        true

    _genwwn:  () ->
        wwn_prefix = 'iqn.2013-01.net.zbx.initiator'
        s1 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        s2 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        s3 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)
        "#{wwn_prefix}:#{s1}#{s2}#{s3}"

    _genwwpn:  () ->
        s = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(3)
        for i in [1..7]
            s1 = Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(3)
            s = "#{s}:#{s1}"
        return s

    rendered: () =>
        super()
        $("form.initr").validate(
            valid_opt(
                rules:
                    wwpn:
                        required: true
                        regex: '^([0-9a-z]{2}:){7}[0-9a-z]{2}$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    wwn:
                        required: true
                        regex: '^(iqn.2013-01.net.zbx.initiator:)(.*)$'
                        duplicated: @sd.initrs.items
                        maxlength: 96
                    'eth-checkbox':
                        required: !@_settings.fc
                        minlength: 1
                messages:
                    wwpn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    wwn:
                        required: "请输入客户端名称"
                        duplicated: "客户端名称已存在"
                        maxlength: "客户端名称长度不能超过96个字母"
                    'eth-checkbox': "请选择至少一个网口"))

    submit: () =>
        if $("form.initr").validate().form()
            portals = []
            for i in @vm.portals when i.checked
                portals.push i.$model.iface
            if @_settings.fc
                @create @vm.initr_wwpn, portals=""
            else
                @create @vm.initr_wwn, portals.join(",")

    create: (wwn, portals) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new InitiatorRest(@sd.host)).create wwn:wwn, portals:portals
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

class VolumeMapModal extends Modal
    constructor: (@sd, @page, @initr) ->
        super "volume-map-modal-", "html/volume_map_modal.html"

    define_vm: (vm) =>
        vm.volumes = @subitems()
        vm.lang = lang.volume_map_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.map-volumes").validate(
            valid_opt(
                rules:
                    'volume-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'volume-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.map-volumes").validate().form()
            selecteds = []
            for i in @vm.volumes when i.checked
                selecteds.push i.$model.name
            @map @initr.wwn, selecteds

    subitems: () =>
        volumes_available = []
        items = subitems @sd.spare_volumes(), id:"", name:"", health:"", cap_sector:"",\
             checked:false
        for i in items
            if i.health == "normal"
                volumes_available.push i
        
        return volumes_available

    map: (wwn, volumes) =>
        @page.frozen()
        chain = new Chain
        for volume in volumes
            chain.chain @_eachMap(wwn, volume)
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
    
    _eachMap: (wwn, volume) =>
        return ()=> (new InitiatorRest @sd.host).map wwn, volume

class VolumeUnmapModal extends Modal
    constructor: (@sd, @page, @initr) ->
        super "volume-unmap-modal-", "html/volume_map_modal.html"

    define_vm: (vm) =>
        vm.volumes = @subitems()
        vm.lang = lang.volume_unmap_modal
        vm.all_checked = false
        vm.submit = @submit

        vm.$watch "all_checked", =>
            for v in vm.volumes
                v.checked = vm.all_checked

    rendered: () =>
        super()
        $("form.map-volumes").validate(
            valid_opt(
                rules:
                    'volume-checkbox':
                        required: true
                        minlength: 1
                messages:
                    'volume-checkbox': "请选择至少一个虚拟磁盘"))
        
    submit: () =>
        if $("form.map-volumes").validate().form()
            selecteds = []
            for i in @vm.volumes when i.checked
                selecteds.push i.$model.name
            @unmap @initr.wwn, selecteds

    subitems: () =>
        items = subitems @sd.initr_volumes(@initr), id:"", name:"", health:"", cap_sector:"",\
             checked:false

    unmap: (wwn, volumes) =>
        @page.frozen()
        chain = new Chain
        for volume in volumes
            chain.chain @_eachunmap(wwn,volume)
        chain.chain @sd.update('initrs')

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
     
    _eachunmap: (wwn,volume) =>
        return () => (new InitiatorRest(@sd.host)).unmap wwn, volume
        
class EthBondingModal extends Modal
    constructor: (@sd, @page) ->
        super "Eth-bonding-modal-", "html/eth_bonding_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.eth_bonding_modal
        vm.options = [
          { key: "负载均衡模式", value: "balance-rr" }
          { key: "主备模式", value: "active-backup" }
        ]
        vm.submit = @submit
        vm.ip = ""
        vm.netmask = "255.255.255.0"

    rendered: =>
        super()

        $("#eth-bonding").chosen()

        Netmask = require("netmask").Netmask
        $.validator.addMethod("validIP", (val, element) =>
            regex = /^\d{1,3}(\.\d{1,3}){3}$/
            if not regex.test val
                return false
            try
                n = new Netmask @vm.ip, @vm.netmask
                return true
            catch error
                return false
        )
        $("form.eth-bonding").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        validIP: true
                    netmask:
                        required: true
                        validIP: true
                messages:
                    ip:
                        required: "请输入IP地址"
                        validIP: "无效IP地址"
                    netmask:
                        required: "请输入子网掩码"
                        validIP: "无效子网掩码"))

    submit: =>
        if $("form.eth-bonding").validate().form()
            @page.frozen()
            @page.dview.reconnect = true
            chain = new Chain
            chain.chain =>
                selected = $("#eth-bonding").val()
                rest = new NetworkRest @sd.host
                rest.create_eth_bonding @vm.ip, @vm.netmask, selected

            @hide()
            show_chain_progress(chain, true).fail =>
                index = window.adminview.find_nav_index @page.dview.menuid
                window.adminview.remove_tab index if index isnt -1
                ###
                @page.settings.removeLoginedMachine @page.dview.host
                @sd.close_socket()
                arr_remove sds, @sd
                @page.attach()
                @page.dview.switch_to_login_page()
                ###

class FsCreateModal extends Modal
    constructor: (@sd, @page, @volname) ->
        super "fs-create-modal-", "html/fs_create_modal.html"

    define_vm: (vm) =>
        vm.mount_dirs = @subitems()
        vm.lang = lang.fs_create_modal
        vm.submit = @submit

    rendered: () =>
        super()
        $("form.fs").validate(
            valid_opt(
                rules:
                    'dir-checkbox':
                        required: true
                        maxlength: 1
                messages:
                    'dir-checkbox': "请选择一个目录作为挂载点"))

    subitems: () =>
        items = []
        used_names=[]

        for fs_o in @sd.filesystem.data
            used_names.push fs_o.name
        for i in [1..2]
            name = "myfs#{i}"
            if name in used_names
                o = path:"/share/vol#{i}", used:true, checked:false, fsname:name
            else
                o = path:"/share/vol#{i}", used:false, checked:false, fsname:name
            items.push o
        return items

    submit: () =>
        if $("form.fs").validate().form()
            dir_to_mount = ""

            for dir in @vm.mount_dirs when dir.checked
                dir_to_mount =  dir.fsname
            @enable_fs dir_to_mount

    enable_fs: (dir) =>
        if dir==''
            @hide()
            (new MessageModal(lang.volume_warning.over_max_fs)).attach()
        else
            @page.frozen()
            chain = new Chain()
            chain.chain(=> (new FileSystemRest(@sd.host)).create_cy dir, @volname)
                .chain @sd.update("filesystem")
            @hide()
            show_chain_progress(chain).done =>
                @page.attach()

class FsChooseModal extends Modal
    constructor: (@sd, @page, @fsname, @volname) ->
        super "fs-choose-modal-", "html/fs_choose_modal.html"

    define_vm: (vm) =>
        vm.filesystems = @subitems()
        vm.lang = lang.fs_choose_modal
        vm.submit = @submit

    rendered: () =>
        super()
        $("form.filesystems").validate(
            valid_opt(
                rules:
                    'fs-checkbox':
                        required: true
                        maxlength: 1
                messages:
                    'fs-checkbox': "请选择一个文件系统类型"))

    subitems: () =>
        items = []
        o = used:true, checked:false, type:"monfs", fsname:"视频文件系统"
        items.push o
        o = used:true, checked:false, type:"xfs", fsname:"通用文件系统"
        items.push o
        return items

    submit: () =>
        if $("form.filesystems").validate().form()
            fs_type = ""
            for filesystem in @vm.filesystems when filesystem.checked
                fs_type =  filesystem.type

            @enable_fs fs_type

    enable_fs: (fs_type) =>
        @page.frozen()
        chain = new Chain()
        chain.chain(=> (new FileSystemRest(@sd.host)).create @fsname, fs_type, @volname)
            .chain @sd.update("filesystem")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            
#####################################################################

class CentralCreateServerModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_create_server_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "服务器"
        vm.close_alert = @close_alert
        
    rendered: () =>
        super()
        $(".basic-toggle-button").toggleButtons()
        $("form.server").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"))
                        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "export"
                if @vm.ip is i.ip
                    $('.alert-error', $('.server')).show()
                    return false
        return true
    submit: () =>
        if @_check()
            if $("form.server").validate().form()
                query = (new MachineRest(@sd.host))
                machine_detail = query.add @vm.ip,'export'
                machine_detail.done (data) =>
                    if data.status is 'success'
                        @page.frozen()
                        chain = new Chain
                        chain.chain => (new MachineRest(@sd.host)).add @vm.ip,'export'
                        chain.chain @sd.update('all')
                        @hide()
                        show_chain_progress(chain).done =>
                            @page.attach()
                            (new MessageModal(lang.central_modal.success)).attach()
                    else
                        (new MessageModal lang.central_modal.error).attach()
                    
class CentralCreateStoreModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_create_store_modal.html"
        @store_ip = ""
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.number_ip = ""
        vm.start_ip = "192.168.2."
        vm.check_info = @check_info
        vm.fattr_process = fattr.process
        vm.fattr_process_step = fattr.process_step
        vm.worker_ip = ''
        vm.ips = ''
        vm.option = "auto"
        vm.text_ip = ""
        vm.close_alert = @close_alert
    subitems: () =>
        ips = [{"ip":"","session":false,"name":"mysql","checked":false,"option":"no"}]
        ips
    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        $("form.docker").validate(
            valid_opt(
                rules:
                    start_ip:
                        required: true
                    number_ip:
                        regex: '^[0-9]*$'
                        required: true
                messages:
                    start_ip:
                        required: "请输入起始ip"
                    number_ip:
                        required: "请输入ip个数"))
        
        $("form.dockers").validate(
            valid_opt(
                rules:
                    text_ip:
                        required: true
                messages:
                    text_ip:
                        required: "请输入需要添加的ip"))
    check_info: (i) =>
        if i is 0
            $("#myTab li:eq(0) a").tab "show"
        if i is 1
            if @vm.option is 'auto'
                $("#myTab li:eq(1) a").tab "show"
            else
                $("#myTab li:eq(2) a").tab "show"
        if i is 2
            $(".alert-error").hide()
            if @vm.option is 'auto'
                $("#myTab li:eq(1) a").tab "show"
            else
                $("#myTab li:eq(2) a").tab "show"
        if i is 3
            if @vm.option is 'auto'
                if $("form.docker").validate().form()
                    $("#myTab li:eq(3) a").tab "show"
                    @change_ip('auto')
            else
                if $("form.dockers").validate().form()
                    $("#myTab li:eq(3) a").tab "show"
                    @change_ip('manual')
                    
    change_ip: (type) =>
        ips = []
        new_ips = []
        
        if type is 'auto'
            a = @vm.start_ip.split('.')
            number_ip = parseInt @vm.number_ip
            start_ip = parseInt a[3]
            for i in [start_ip...start_ip + number_ip]
                ip = '192.168.2.' + i
                ips.push ip
        else
            ips = @vm.text_ip.split(',')
            
        if ips.length >= 4
            p = 0
            for o in ips
                if p < 2
                    new_ips.push o
                else if p is 2
                    new_ips.push "...."
                else if p is ips.length - 1
                    new_ips.push o
                p++
            new_ips = new_ips.join ","
            @vm.ips = new_ips
        else
            @vm.ips = ips
            
        @store_ip = ips
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "storage"
                if i.ip in @store_ip
                    $('.alert-error', $('.dockers')).show()
                    return false
        return true
                
    submit: () =>
        if @_check()
            for i in @store_ip
                @page.frozen()
                chain = new Chain
                chain.chain => (new MachineRest(@sd.host)).add i,'storage'
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.success)).attach()
                        
class CentralCreateClientModal extends Modal
    constructor: (@sd, @page) ->
        super "central-client-modal-", "html/central_create_client_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "客户端"
        vm.close_alert = @close_alert
        
    rendered: () =>
        super()
        $(".basic-toggle-button").toggleButtons()
        $("form.client").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"))
                        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "client"
                if @vm.ip is i.ip
                    $('.alert-error', $('.client')).show()
                    return false
        return true
        
    submit: () =>
        if @_check()
            if $("form.client").validate().form()
                query = (new MachineRest(@sd.host))
                machine_detail = query.add @vm.ip,'client'
                machine_detail.done (data) =>
                    if data.status is 'success'
                        @page.frozen()
                        chain = new Chain
                        chain.chain => (new MachineRest(@sd.host)).add @vm.ip,'client'
                        chain.chain @sd.update('all')
                        @hide()
                        show_chain_progress(chain).done =>
                            @page.attach()
                            (new MessageModal(lang.central_modal.success)).attach()
                    else
                        (new MessageModal lang.central_modal.error).attach()
                        
class CentralExpandModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_expand_modal.html"
        @tips = ""
        @machine = ""
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.options = @options()
        vm.store = @count_machines()
        vm.next = @next
        vm.fattr_process_step = fattr.process_step
        vm.all_checked = false
        vm.tips = @tips
        vm.$watch "all_checked", =>
            for r in vm.store
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        $("#node").chosen()
        
    subitems: () =>
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub
        
    count_options: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.export is @message)
        sub
        
    count_machines: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.status is false)
        sub
        ###
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub###
        
    options: () =>
        option = [0]
        options = []
        
        ((option.push i.cid) for i in @count_options() when i.cid not in option)
        max = Math.max.apply(null,option)
        if max is 0
            [{key:1,value:"1"}]
        else
            ((options.push {key:i,value:i.toString()}) for i in [1..max + 1])
            options
            
    next: (i) =>
        if i is 0
            $("#myTab li:eq(0) a").tab "show"
        if i is 1
            $("#myTab li:eq(1) a").tab "show"
        if i is 2
            if @_tips()
                $("#myTab li:eq(2) a").tab "show"
            else
                (new MessageModal(lang.central_modal.choose)).attach()
                
    _tips: () =>
        selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        @machine = machine.join ","
        if @machine
            @vm.tips = "确认要将以下机器#{@machine}添加到节点#{selected}吗?"
            true
            
       
    submit: () => 
        #selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        #@monitor(machine)
        @machine = machine.join ","
        
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).export @message,@machine
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.expand_success)).attach()
        
    monitor: (machine) =>
        for i in machine
            query = (new MachineRest(@sd.host))
            machine_detail = query.monitor "a", i, 24, "storage"
            
        for j in @sd.centers.items
            if j.Devtype is "export" and j.Ip is @message
                return
        machine_detail = query.monitor "a", @message, 24, "export"
        
class CentralStartModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-server-modal-", "html/central_start_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.fattr_server_health = fattr.server_health
        vm.node = @node()
        vm.all_checked = false
        vm.start = @start
        vm.stop = @stop
        vm.$watch "all_checked", =>
            for r in vm.store
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        @vm.node = @node()
        @data_table = $("#start-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
                
    subitems: () =>
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",master:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i)for i in items when i.devtype is 'storage' and i.master is @message)
        sub
        
    node: () =>
        option = [0]
        options = []
        ((option.push i.cid )for i in @subitems() when i.cid not in option)
        max = Math.max.apply(null,option)
        if max is 0
            options
        else
            for i in [1..max]
                options.push {cid:i}
            for i in @subitems()
                for j in options
                    if i.cid is j.cid
                        j.status = i.status
            options
            
    start: (cid) =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).storage @message,cid
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.start_success)).attach()
            
    stop: (cid) =>
        ip = []
        ((ip.push i.ip )for i in @subitems() when i.cid is cid)
        ip = ip.join ","
        
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).rozostop 'storage',ip
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.stop_success)).attach()
            
class CentralDownloadLogModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_downloadlog_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_warning
        vm.submit = @submit
        vm.ip = ""
                
    rendered: () =>
        super()
                
    submit: () =>
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).download_log @vm.ip
        chain.chain @sd.update('all')
        show_chain_progress(chain).done =>
            console.log 123
        
class CentralManualModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_manual_modal.html"
        @_settings = new SettingsManager
        
    define_vm: (vm) =>
        vm.lang = lang.central_manual
        vm.submit = @submit
        vm.ip = ""
        ###vm.options = [
          { key: "请选择", value: "no" }
          { key: "存储", value: "storage" }
          { key: "主服务器", value: "master" }
          { key: "备服务器", value: "backup" }
        ]###
        vm.options = [
          { key: "请选择", value: "" }
          { key: "存储", value: "storage" }
          { key: "服务器", value: "master" }
        ]
        vm.close_alert = @close_alert
    
    close_alert: (e) =>
        $(".alert-error").hide()
        
    rendered: () =>
        super()
        $.validator.addMethod("same", (val, element) =>
            selected = $("#manual").val()
            for i in @sd.centers.items
                if i.Ip is val and i.Devtype is selected
                    return false
            return true
        , "机器已监控")
        
        $("form.manual").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        regex: /\d{1,3}(\.\d{1,3})$/
                        same:true
                    machinetype:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"
                    machinetype:
                        required: "请选择类型"))
                        
        #$("#manual").chosen()
        $("#add_ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.ip = item
        )
        
    count_machine: (selected) =>
        if selected is "master" or selected is "backup"
            for i in @sd.centers.items
                if i.Devtype is "export" and i.Ip is @vm.ip
                    (new MessageModal @vm.lang.add_server_error).attach()
                    return false
        else
            for i in @sd.centers.items
                if i.Devtype is "storage" and i.Ip is @vm.ip
                    (new MessageModal @vm.lang.add_store_error).attach()
                    return false
        return true
        
    _init_device:() =>
        @_settings.addUsedMachine @vm.ip
        @_settings.addLoginedMachine @vm.ip
        @_settings.addSearchedMachine @vm.ip
        return
        
    submit: () =>
        if $("form.manual").validate().form()
            selected = $("#manual").val()
            if selected is "" or @vm.ip is ""
                $('.alert-error').show();
                return
            _type = if selected is "storage" then "storage" else "export"
            if @count_machine(selected)
                #@_init_device()
                @page.frozen()
                chain = new Chain
                chain.chain => 
                    query = (new MachineRest(@sd.host)).monitor "a", @vm.ip, 24, _type, selected
                    query.done (data) =>
                        if data.status is "error"
                            (new MessageModal(lang.central_error.message(data.errcode,data.description))).attach()
                        else
                            (new MessageModal lang.central_search_modal.monitor_success).attach()
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain).done (data)=>
                    #@tips(@vm.ip)
                    @page.attach()
            
    tips:(ip) =>
        try
            datas = {}
            datas[ip] = 0
            ((datas[ip] = datas[ip] + 1 )for j in @sd.stores.items.journals when j.ip is ip)
            if datas[ip] > 0
                if @type is "storage"
                    types = "存储"
                else
                    types = "元数据"
                @show_tips(ip,datas[ip],types)
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

class CentralAddEmailModal extends Modal
    constructor: (@sd, @page) ->
        super "central-add-email-modal-", "html/central_add_email_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_email
        vm.submit = @submit
        vm.email = ""
        vm.level = ""
        vm.ttl = 120
        vm.close_alert = @close_alert
        vm.options = [
          { key: "请选择", value: "" }
          { key: "高", value: 3 }
          { key: "中", value: 2 }
          { key: "低", value: 1 }
        ]
    
    close_alert: (e) =>
        $(".alert-error").hide()
                
    rendered: () =>
        super()
        #$("#addemail").chosen()
        $("form.add_email").validate(
            valid_opt(
                rules:
                    email:
                        regex: '^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$'
                        required: true
                    level:
                        required: true
                    ttl:
                        regex: '^[0-9]*$'
                        required: true
                messages:
                    email:
                        required: "请输入邮箱地址"
                    level:
                        required: "请选择告警等级"
                    ttl:
                        required: "请输入告警时间"))
                
    submit: () =>
        if $("form.add_email").validate().form()
            selected = $("#addemail").val()
            if @vm.email is "" or selected is "" or @vm.ttl is ""
                $(".alert-error").show()
                return
            else
                @page.frozen()
                chain = new Chain
                chain.chain => (new MachineRest(@sd.host)).add_email  @vm.email,selected,@vm.ttl
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain).done (data)=>
                    @page.attach()
                    (new MessageModal lang.central_email.success_add).attach()
            
class CentralChangeValueModal extends Modal
    constructor: (@sd, @page, @_type,@_apply,@_normal,@_bad,@_uid) ->
        super "central-change-value-modal-", "html/central_change_value_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_value
        vm.submit = @submit
        vm.normal = @_normal
        vm.bad = @_bad
        vm.message = @_type
        vm.apply = @_apply
        
    rendered: () =>
        super()
        $.validator.addMethod("morethan", (val, element) =>
            sub = []
            if @vm.normal >= @vm.bad
                return false
            return true
        , "普通阈值应小于严重阈值")
        
        $("form.change_value").validate(
            valid_opt(
                rules:
                    normal:
                        regex: '^\\d+(\\.\\d+)?$'
                        required: true
                        range:[0,100]
                        morethan:true
                    bad:
                        regex: '^\\d+(\\.\\d+)?$'
                        required: true
                        range:[0,100]
                        morethan:true
                messages:
                    normal:
                        required: "请输入普通阈值"
                        range: $.format("阈值范围为{0}到{1}")
                    bad:
                        required: "请输入严重阈值"
                        range: $.format("阈值范围为{0}到{1}")))
                        
    value: () =>
        if @message is "cpu"
            return "处理器"
        else if @message is "diskcap"
            return "元数据容量"
        else if @message is "cache"
            return "缓存"
        else if @message is "mem"
            return "内存"
        else if @message is "system"
            return "系统空间"
        else if @message is "filesystem"
            return "存储空间"
            
    submit: () =>
        if $("form.change_value").validate().form()
            #if @vm.normal >= @vm.bad or @vm.normal > 100 or @vm.bad > 100
            #    return (new MessageModal lang.central_value.error_change).attach()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_value @_uid,@vm.normal,@vm.bad
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.central_value.success_change).attach()
                
class CentralHandleLogModal extends Modal
    constructor: (@sd, @page) ->
        super "central-handle-log-modal-", "html/central_handle_log_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_handle_log
        vm.submit = @submit
        vm.normal = ""
        vm.bad = ""
        vm.message = @message
        vm.journal_unhandled = @subitems()
        vm.fattr_journal_status = fattr.journal_status
        vm.all_checked = false
        vm.close_alert = @close_alert
        vm.$watch "all_checked", =>
            for v in vm.journal_unhandled
                v.checked = vm.all_checked
                
    rendered: () =>
        super()
        @vm.journal_unhandled = @subitems()
        @data_table= $("#log-table").dataTable dtable_opt(retrieve: true, bSort: false)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        $scroller = $("#journals-scroller")
        $scroller.slimScroll
            size: '7px'
            color: '#a1b2bd'
            position: 'right'
            height: $scroller.attr("data-height")
            alwaysVisible: true
            railVisible: false
            disableFadeOut: true
            railDraggable: true
    
    close_alert: (e) =>
        $(".alert-error").hide()
        
    subitems: () =>
        #console.log();
        try
            arrays = []
            for i in @sd.journals.items
                i.created = i.created.replace("-","/").replace("-","/").replace("T","-").replace("+08:00","")
                if !i.status
                    i.chinese_status = "未处理"
                    i.checked = false
                    arrays.push i
            arrays.reverse()
        catch error
            return []
        
    submit: () =>
        selected = ($.extend({},i.$model) for i in @vm.journal_unhandled when i.checked)
        if !selected.length
            return $('.alert-error').show()
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in selected
            chain.chain ->
                (rest.handle_log_pro selected[i].uid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_handle_log.success)).attach()
            
class CentralUnmonitorProModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-delete-modal-","html/central_delete_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_delete_modal
        vm.submit = @submit
        vm.message = @message

    rendered: () =>
        super()
        
    submit: () =>
        query = @message
        @page.frozen()
        chain = new Chain
        rest = new MachineRest @sd.host
        i = 0
        for disk in query
            chain.chain ->
                (rest.unmonitor_pro query[i].uuid).done -> i += 1
        chain.chain @sd.update("all")
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(@vm.lang.delete_success)).attach()
                
class CentralUnmonitorModal extends Modal
    constructor: (@sd, @page) ->
        super "central-unmonitor-modal-", "html/central_unmonitor_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_unmonitor
        vm.submit = @submit
        vm.device = @subitems()
        vm.fattr_monitor_status = fattr.monitor_status
        vm.all_checked = false
        vm.close_alert = @close_alert
        vm.$watch "all_checked", =>
            for v in vm.device
                v.checked = vm.all_checked
                
    rendered: () =>
        super()
        #@vm.device = @subitems()
        @data_table= $("#unmonitor-table").dataTable dtable_opt(retrieve: true, bSort: false)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
      
            
    subitems: () =>
        if @sd.centers.items != null
            tmp = []
            items = subitems @sd.centers.items, Uuid:"", Ip:"", Slotnr:"", Created: "",Devtype:"",Status:"",checked:false,Role:""
            for i in items 
                if i.Devtype is "storage"
                    i.Chinese_devtype = "存储"
                else
                    i.Chinese_devtype = "服务器"
                
                if i.Role is "master"
                    i.Chinese_role = "主服务器"
                else if i.Role is "backup"
                    i.Chinese_role = "备服务器"
                else
                    i.Chinese_role = "存储"
                tmp.push i
            tmp
            
    close_alert:()=>
        $(".alert-error").hide()
        
    submit: () =>
        selected = ($.extend({},i.$model) for i in @vm.device when i.checked)
        if selected.length isnt 0
            chain = new Chain
            rest = new MachineRest @sd.host
            i = 0
            for disk in selected
                chain.chain ->
                    (rest.unmonitor selected[i].Uuid).done -> i += 1
            chain.chain @sd.update("all")
            @hide()
            show_chain_progress(chain).done =>
                @page.attach()
                (new MessageModal(lang.central_unmonitor.success)).attach()
        else
            $(".alert-error").show()
            ###@hide()
            result = true
            for i in selected
                query = (new MachineRest(@sd.host))
                machine_detail = query.unmonitor i.Uuid
                machine_detail.done (data) =>
                    console.log data
                    if data.status isnt 'success'
                        result = false

            chain = new Chain
            chain.chain @sd.update("all")
            show_chain_progress(chain).done ->
                console.log "Refresh Storage Data"
            @page.attach()
            if result
                (new MessageModal(lang.central_unmonitor.success)).attach()
            else
                (new MessageModal(lang.central_unmonitor.error)).attach()###
                
class CentralChangeEmailModal extends Modal
    constructor: (@sd, @page, @_uid) ->
        super "central-change-email-modal-", "html/central_change_email_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_email
        vm.submit = @submit
        vm.address = ""
        vm.ttl = ""
        vm.options = [
          { key: "低", value: 1 }
          { key: "中", value: 2 }
          { key: "高", value: 3 }
        ]
        
    rendered: () =>
        super()
        @init()
        $("form.change_email").validate(
            valid_opt(
                rules:
                    level:
                        regex: '^[0-9]*$'
                        required: true
                    ttl:
                        regex: '^[0-9]*$'
                        required: true
                messages:
                    level:
                        required: "请输入告警等级"
                    ttl:
                        required: "请输入告警时间"))
                      
    init:() =>
        for i in @sd.emails.items
            if i.uid is @_uid
                @vm.address = i.address
                @vm.ttl = i.ttl
                $("#changeemail option[value='"+i.level+"']").attr("selected","selected");  
                $("#changeemail").chosen();
                return

    submit: () =>
        selected = $("#changeemail").val()
        if $("form.change_email").validate().form()
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).change_email @_uid,selected,@vm.ttl
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                @page.attach()
                (new MessageModal lang.central_value.success_change).attach()
                
                
class CentralCombineServerModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_combine_server_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_combine
        vm.submit = @submit
        vm.options_backup = @options_backup()
        vm.options_master = @options_master()
        #vm.options_client = @options_client()
        vm.message = @message
        
    rendered: () =>
        super()
        $("#backup").chosen()
        $("#master").chosen()
        #$("#client").chosen()
       
    options_master: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:"",role:""
        options = [{key:"请选择",value:"no"}]
        for i in arrays
            if i.devtype is 'export'
                if i.role is ""
                    options.push {key:i.ip,value:i.ip}
        options
        
    options_backup: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:"",role:""
        options = [{key:"请选择",value:"no"}]
        for i in arrays
            if i.devtype is 'export'
                if i.role is ""
                    options.push {key:i.ip,value:i.ip}
        options
        
    options_client: () =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:"",role:""
        options = [{key:"请选择",value:"no"}]
        for i in arrays
            if i.devtype is 'client' and !i.status
                options.push {key:i.ip,value:i.ip}
        options
            
        
    submit: () =>
        if $("form.manual").validate().form()
            selected_backup = $("#backup").val()
            selected_master = $("#master").val()
            if selected_backup is "no" or selected_master is "no"
                return
            if selected_backup is selected_master
                (new MessageModal lang.central_combine.same_ip).attach()
                return
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).combine selected_master,selected_backup,@message
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done (data)=>
                (new MessageModal lang.central_combine.success).attach()
                @page.attach()
            .fail =>
                (new MessageModal lang.central_combine.error).attach()
                
class CentralCreateMachineModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_create_machine_modal.html"
        @_settings = new SettingsManager
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "服务器"
        vm.close_alert = @close_alert
        vm.error_tips = ""
        vm.options = [
          { key: "请选择", value: "" }
          { key: "服务器", value: "export" }
          { key: "存储", value: "storage" }
          #{ key: "客户端", value: "client" }
        ]
        
    rendered: () =>
        super()
        #$("#addmachine").chosen()
        $("#add_ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.ip = item
        )
        
        $.validator.addMethod("same", (val, element) =>
            selected = $("#addmachine").val()
            for i in @sd.clouds.items
                if i.ip is val and i.devtype is selected
                    return false
            return true
        , "机器已存在")
        
        $(".basic-toggle-button").toggleButtons()
        $("form.create").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        regex: /\d{1,3}(\.\d{1,3})$/
                        same:true
                    machinetype:
                        required: true
                messages:
                    ip:
                        required: "请输入ip地址"
                    machinetype:
                        required: "请选择类型"))
                        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        selected = $("#addmachine").val()
        for i in @sd.clouds.items
            if @vm.ip is i.ip and selected is i.devtype
                @vm.error_tips = "地址已存在,请重新输入"
                $('.alert-error').show()
                return false
        return true
        
    _init_device:() =>
        @_settings.addUsedMachine @vm.ip
        @_settings.addLoginedMachine @vm.ip
        @_settings.addSearchedMachine @vm.ip
        return
        
    submit: () =>
        if $("form.create").validate().form()
            if @_check()
                selected = $("#addmachine").val()
                if selected is "" or @vm.ip is ""
                    @vm.error_tips = "请填写完整"
                    $(".alert-error").show()
                    return
                ###
                @page.frozen()
                chain = new Chain
                chain.chain => (new MachineRest(@sd.host)).add @vm.ip,selected
                chain.chain @sd.update('all')
                @hide()
                (show_chain_progress chain,true).done (data)=>
                    console.log(data)
                    @page.attach()
                    (new MessageModal(lang.central_modal.success)).attach()
                ###
                #@_init_device()
                @page.frozen()
                chain = new Chain
                chain.chain =>
                    query = new MachineRest(@sd.host).add @vm.ip,selected
                    query.done (data) =>
                        if data.status is "success"
                            (new MessageModal(lang.central_modal.success)).attach()
                        else
                            (new MessageModal(lang.central_modal._error)).attach()
                chain.chain @sd.update('all')
                @hide()
                show_chain_progress(chain, true).done =>
                    @page.attach()

class CentralChangeSambaModal extends Modal
    constructor: (@sd, @page, @uuid) ->
        super "central-modal-", "html/central_change_samba_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.size = "4U"
        vm.version = "ZS2000"
        vm.type = "服务器"
        vm.close_alert = @close_alert
        vm.colonys = @subitems()
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.colonys
                r.checked = vm.all_checked
        vm.options = [
          { key: "请选择", value: "no" }
          { key: "服务器", value: "export" }
          { key: "存储", value: "storage" }
          { key: "客户端", value: "client" }
        ]
        
    rendered: () =>
        super()
        @vm.colonys = @subitems()
        @data_table = $("#colony-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        
       
    subitems:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,export:"",role:""
                
        ###for i in arrays
            if i.devtype is 'export'
                if i.role is ""
                    options.push {key:i.ip,value:i.ip}###
        return [{"ip":"192.168.2.120","checked":false,"devtype":"存储"},{"ip":"192.168.2.121","checked":false,"devtype":"服务器"},{"ip":"192.168.2.122","checked":false,"devtype":"客户端"}]
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    _check: () =>
        for i in @sd.clouds.items
            if i.devtype is "export"
                if @vm.ip is i.ip
                    $('.alert-error', $('.server')).show()
                    return false
        return true
        
    submit: () =>
        selected = $("#addmachine").val()
        if selected is "no"
            return
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).add @vm.ip,selected
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.success)).attach()

class CentralCreateColonyModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_create_colony_modal.html"
        
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.master_ip = ""
        vm.backup_ip = ""
        vm.client = ""
        vm.storage = ""
        vm.colony = ""
        vm.options_export = @options_export()
        vm.options_client = @options_client()
        vm.options_backup = @options_backup()
        vm.storages = @storages()
        vm.close_alert = @close_alert
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.storages
                r.checked = vm.all_checked

    rendered: () =>
        super()
        @vm.storages = @storages()
        #$("#export_option").chosen()
        #$("#client_option").chosen()
        @vm.options_export = @options_export()
        @vm.options_client = @options_client()
        @vm.options_backup = @options_backup()
        
        $.validator.addMethod("store", (val, element) =>
            sub = []
            for i in @vm.storages
                if i.checked
                    sub.push i.ip
            if sub.length < 4 or sub.length%4 isnt 0
                return false
            return true
        , "存储数目要求为4的倍数")
        
        $.validator.addMethod("colonysame", (val, element) =>
            sub = []
            for i in @sd.colonys.items
                if i.cid is parseInt val
                    return false
            return true
        , "集群名称已存在")
        
        $("form.colony").validate(
            valid_opt(
                rules:
                    colony:
                        required: true
                        regex: "^[0-9]*$"
                        #duplicated: @sd.colonys.items
                        colonysame:true
                    master_ip:
                        required: true
                    storage:
                        required: true
                    #client:
                        #required: true
                    export:
                        required: true
                    selector:
                        store:true
                messages:
                    colony:
                        required: "请输入集群名称"
                        regex: "输入格式不正确，集群名称为数字"
                        duplicated: "集群已存在"
                    master_ip:
                        required: "请输入主服务器地址"
                    storage:
                        required: "请输入存储地址"
                    #client:
                        #required: "请选择地址"
                    export:
                        required: "请选择地址"))
                        
    storages:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:"",cluster: ""
        sub = []
        for i in arrays
            if i.devtype is 'storage'
                i.name = '存储'
                sub.push i
        sub
        
    subitems:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:"",cluster: ""
        arrays
        
    options_export: () =>
        options = [{key:'请选择',value:''}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'export')
        options
        
    options_backup: () =>
        options = [{key:'请选择',value:''}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'export' and i.cluster is "")
        options
        
    options_client: () =>
        options = [{key:'请选择',value:''}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype is 'client' and i.cluster is "")
        options
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    submit: () =>
        if $("form.colony").validate().form()
            sub = []
            for i in @vm.storages
                if i.checked
                    sub.push i.ip
            if sub.length < 4 or sub.length%4 isnt 0
                return
            sub = sub.join ","
            
            selected_export = $("#export_option").val()
            selected_client = $("#client_option").val()
            if selected_export is "" or sub is ""
                return $('.alert-error').show();
                
            @page.frozen()
            chain = new Chain
            chain.chain => (new MachineRest(@sd.host)).create_colony selected_export,sub,selected_client,@vm.colony
            chain.chain @sd.update('all')
            @hide()
            show_chain_progress(chain).done =>
                @page.attach()
                (new MessageModal(lang.central_modal.success)).attach()

class CentralShowStorageDetailModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_show_storage_detail_modal.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.machine_detail = @subitems()
                
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.machine_detail = @subitems()
  
    rendered: () =>
        super()
        ###@data_table = $("#detail-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        ###
        
    subitems:() =>
        try
            tmp = []
            stats = @sd.stats.items[@sd.stats.items.length - 1].storages;
            for i in stats
                cap_used = 0
                if i.info[0].cache_used isnt 0
                    cache = i.info[0].cache_used / i.info[0].cache_total
                else
                    cache = 0
                dist = {"system":0,"var":0,"cap":0}
                
                if i.info[0].gateway.length is 1
                    if i.info[0].gateway[0].name is "eth0"
                        speed = i.info[0].gateway[0].speed + '/无'
                    else
                        speed = '无/' + i.info[0].gateway[0].speed
                else if i.info[0].gateway.length is 2
                    speed = i.info[0].gateway[0].speed + '/' + i.info[0].gateway[1].speed
                else
                    speed = i.info[0].gateway[0].speed + '/' + i.info[0].gateway[1].speed + '/...'
                        
                for j in i.info[0].df
                    dist[j.name] = j.used_per
                   
                if i.info[0].fs.length
                    for h in i.info[0].fs
                        cap_used = cap_used + h.used_per                
                    cap_used = cap_used/i.info[0].fs.length
                    
                tmp.push {"speed":speed,"ip":i.ip,"cpu":parseInt(i.info[0].cpu),"cache":parseInt(cache),"mem":parseInt(i.info[0].mem),"system":parseInt(dist.system),"var":parseInt(dist.var),"cap":parseInt(cap_used)}
            tmp
        catch e
            return []
            ###a = [{"ip":"192.168.2.102","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.103","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.111","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.188","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.19","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12}]
            ###

    submit: () =>
        @hide()

class CentralShowServerDetailModal extends Modal
    constructor: (@sd, @page) ->
        super "central-server-modal-", "html/central_show_server_detail_modal.html"
        
        $(@sd.stats).on "updated", (e, source) =>
            if @has_rendered
                @vm.machine_detail = @subitems()
                
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.machine_detail = @subitems()
  
    rendered: () =>
        super()
        ###@data_table = $("#detail-table").dataTable dtable_opt(retrieve: true)
        $(".dataTables_filter input").addClass "m-wrap small"
        $(".dataTables_length select").addClass "m-wrap small"
        ###
    subitems:() =>
        try
            tmp = []
            stats = @sd.stats.items[@sd.stats.items.length - 1].exports;
            for i in stats
                dist = {"system":0,"var":0,"docker":0,"tmp":0}
                for j in i.info[0].df
                    dist[j.name] = j.used_per
                    
                tmp.push {"ip":i.ip,"cpu":i.info[0].cpu,"mem":i.info[0].mem,"system":dist.system,"var":dist.var,"docker":dist.docker,"tmp":dist.tmp}
            tmp
        catch e
            return []
            ###a = [{"ip":"192.168.2.102","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.103","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.111","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.188","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12},\
            {"ip":"192.168.2.19","cpu":9,"cache":12,"mem":22,"system":21,"var":8,"cap":12}]
            ###
        
    submit: () =>
        @hide()
        
class CentralProExpandModal extends Modal
    constructor: (@sd, @page, @message) ->
        super "central-worker-modal-", "html/central_expand_modal.html"

    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.message = @message
        vm.options = @options()
        vm.store = @count_machines()
        vm.next = @next
        vm.fattr_process_step = fattr.process_step
        vm.all_checked = false
        vm.tips = @tips
        vm.$watch "all_checked", =>
            for r in vm.store
                r.checked = vm.all_checked
                
    rendered: () =>
        super()
        $("#myTab li:eq(0) a").tab "show"
        $("#node").chosen()
        
    subitems: () =>
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub
        
    count_options: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.export is @message)
        sub
        
    count_machines: () =>
        sub = []
        ((sub.push i) for i in @subitems() when i.status is false)
        sub
        ###
        sub = []
        items = subitems @sd.clouds.items,cid:"",devtype:"",expand:"",export:"",ip:"",status:"", uuid:"", checked:false
        ((sub.push i) for i in items when i.devtype is 'storage')
        sub###
        
    options: () =>
        option = [0]
        options = []
        
        ((option.push i.cid) for i in @count_options() when i.cid not in option)
        max = Math.max.apply(null,option)
        if max is 0
            [{key:1,value:"1"}]
        else
            ((options.push {key:i,value:i.toString()}) for i in [1..max + 1])
            options
            
    next: (i) =>
        if i is 0
            $("#myTab li:eq(0) a").tab "show"
        if i is 1
            $("#myTab li:eq(1) a").tab "show"
        if i is 2
            if @_tips()
                $("#myTab li:eq(2) a").tab "show"
            else
                (new MessageModal(lang.central_modal.choose)).attach()
                
    _tips: () =>
        selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        @machine = machine.join ","
        if @machine
            @vm.tips = "确认要将以下机器#{@machine}添加到节点#{selected}吗?"
            true
            
       
    submit: () => 
        #selected = $("#node").val()
        machine = []
        ((machine.push i.ip) for i in @vm.store when i.checked)
        #@monitor(machine)
        @machine = machine.join ","
        
        @page.frozen()
        chain = new Chain
        chain.chain => (new MachineRest(@sd.host)).export @message,@machine
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain).done =>
            @page.attach()
            (new MessageModal(lang.central_modal.expand_success)).attach()
        
    monitor: (machine) =>
        for i in machine
            query = (new MachineRest(@sd.host))
            machine_detail = query.monitor "a", i, 24, "storage"
            
        for j in @sd.centers.items
            if j.Devtype is "export" and j.Ip is @message
                return
                
        machine_detail = query.monitor "a", @message, 24, "export"
        
class CentralProStartModal extends Modal
    constructor: (@sd, @page, @dev) ->
        super "central-start-pro-modal-", "html/central_start_pro_modal.html", style: "min-width:670px;"
        
        $(@sd).one 'CreateFilesystem', (e, event) =>
            @hide()

    define_vm: (vm) =>
        vm.lang = lang.raid_create_modal
        vm.name = ""
        vm.level = "5"
        #vm.chunk = "64KB"
        vm.rebuild_priority = "low"
        vm.sync = false
        vm.submit = @submit
        vm.totals = @totals()
        vm.close_alert = @close_alert
        vm.show_loading = false
        
    rendered: () =>
        super()
        @vm.show_loading = false
        @dsuui = new CentralProStartDSUUI(@sd, "#dsuui",@dev)
        @dsuui.attach()
        @add_child @dsuui
        $("input:radio").uniform()
        $(".basic-toggle-button").toggleButtons()
        $("#sync").change =>
            @vm.sync = $("#sync").prop "checked"

        dsu = @prefer_dsu_location()
        [raids...] = (disk for disk in @prodisks()\
                                when disk.role is 'unused'\
                                and disk.location.indexOf(dsu) is 0)
        [cap_sector...] = (raid.cap_sector for raid in raids)
        total = []
        cap_sector.sort()
        for i in [0...cap_sector.length]
            count = 0
            for j in [0...cap_sector.length]
                if cap_sector[i] is cap_sector[j]
                    count++
            total.push([cap_sector[i],count])
            i+=count
            
        for k in [0...total.length]
            if total[k][1] >= 3
                [Raids...] = (disk for disk in raids\
                                when disk.cap_sector is total[k][0])
                for s in [0...3]
                    @dsuui.check_disks Raids[s]
                    @dsuui.active_tab dsu
                #@dsuui.check_disks Raids[3], "spare"
                break
                
        $.validator.addMethod("min-raid-disks", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return false
            else if level is 0 and nr < 1
                return false
            else if level is 1 and nr isnt 2
                return false
            else if level is 10 and nr%2 != 0  and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks().length
            if level is 5 and nr < 3
                return "级别5阵列最少需要3块磁盘"
            else if level is 0 and nr < 1
                return "级别0阵列最少需要1块磁盘"
            else if level is 1 and nr != 2
                return "级别1阵列仅支持2块磁盘"
            else if level is 10 and nr%2 != 0 and nr > 0
                return "级别10阵列数据盘必须是偶数个"
        )
        $.validator.addMethod("spare-disks-support", (val, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return false
            else if level is 10 and nr > 0
                return false
            else
                return true
        ,(params, element) =>
            level = parseInt @vm.level
            nr = @dsuui.get_disks("spare").length
            if level is 0 and nr > 0
                return '级别0阵列不支持热备盘'
            else if level is 10 and nr > 0
                return '级别10阵列不支持热备盘'
        )
        $.validator.addMethod("min-cap-spare-disks", (val, element) =>
            level = parseInt @vm.level
            if level != 5
                return true
            map = {}
            for disk in @prodisks()
                map[disk.location] = disk

            spare_disks = (map[loc] for loc in @dsuui.get_disks("spare"))
            data_disks = (map[loc] for loc in @dsuui.get_disks())
            min_cap = Math.min.apply(null, (d.cap_sector for d in data_disks))
            for s in spare_disks
                if s.cap_sector < min_cap
                    return false
            return true
        , "热备盘容量太小"
        )
        
        $("form.raid").validate(
            valid_opt(
                rules:
                    name:
                        required: true
                        regex: "^[_a-zA-Z][-_a-zA-Z0-9]*$"
                        duplicated: @sd.raids.items
                        maxlength: 64
                    "raid-disks-checkbox":
                        "min-raid-disks": true
                        maxlength: 24
                    "spare-disks-checkbox":
                        "spare-disks-support": true
                        "min-cap-spare-disks": true
                messages:
                    name:
                        required: "请输入阵列名称"
                        duplicated: "阵列名称已存在"
                        maxlength: "阵列名称长度不能超过64个字母"
                    "raid-disks-checkbox":
                        maxlength: "阵列最多支持24个磁盘"))
        
    data_refresh: (result) =>
        try
            chain = new Chain
            chain.chain @sd.update("all")
            @hide()
            show_chain_progress(chain).done ->
                if result
                    (new MessageModal "启动成功").attach()
                else
                    (new MessageModal "启动失败").attach()
            @page.attach()
        catch e
            console.log e
        
    close_alert: (e) =>
        $(".alert-error").hide()
        
    totals:() =>
        tmp = []
        for i in @sd.machinedetails.items
            tmp.push {"ip":i.ip,"level":"5","name":"log"}
        tmp
        
    prodsus:() =>
        tmp = []
        for i in @sd.machinedetails.items
            if i.ip in @dev.storage
                tmp.push {"location":i.dsus.location,"support_disk_nr": i.dsus.support_disk_nr,"ip":i.ip}
        tmp
       
    prodisks:() =>
        tmp = []
        for i in @sd.machinedetails.items
            for h in i.disks
                tmp.push h
        tmp
        
    _check_disks:(disks) =>
        for dsu in disks
            if dsu.level is "5"
                if dsu.selected < 3
                    return false
            else
                if dsu.selected < 2
                    return false
                   
            ary = dsu.cap
            s = ary.join(",")+","
            count = 0
            for i in ary
                if(s.replace(i+",","").indexOf(i+",")>-1) 
                    count = count + 1
                   
            if count isnt dsu.cap.length
                return false
                
        return true
                
    submit: () =>
        if @vm.show_loading
            return
        arrays = @dsuui.get_disks()
        for i in arrays
            i.level = @vm.level
            
        if @_check_disks(arrays)
            $(".alert-error").hide()
            @vm.show_loading = true
            @page.frozen()
            rest = new MachineRest(@sd.host)
            query = rest.prostart JSON.stringify(arrays)
            query.done (data) =>
                if data.status is "error"
                    (new MessageModal(lang.central_error.message(data.errcode,data.description))).attach()
        else
            $('.alert-error').show()

    create: (name, level, chunk, raid_disks, spare_disks, rebuild, sync) =>
        @page.frozen()
        raid_disks = raid_disks.join ","
        spare_disks = spare_disks.join ","
        chain = new Chain
        chain.chain(=> (new RaidRest(@sd.host)).create(name: name, level: level,\
            chunk: chunk, raid_disks: raid_disks, spare_disks:spare_disks,\
            rebuild_priority:rebuild, sync:sync, cache:''))
            .chain @sd.update("raids")

        @hide()
        show_chain_progress(chain).done =>
            @page.attach()

    count_dsu_disks: (dsu) =>
        return (disk for disk in @prodisks()\
                         when disk.role is 'unused'\
                         and disk.location.indexOf(dsu.location) is 0).length

    prefer_dsu_location: () =>
        for dsu in @prodsus()
            if @count_dsu_disks(dsu) >= 3
                return dsu.location
        return if @prodsus().length then @prodsus()[0].location else '_'
        
class CentralProStartDSUUI extends AvalonTemplUI
    constructor: (@sd, parent_selector, @dev ,@enabled=['data','spare'], @on_quickmode=false) ->
        super "dsuui-", "html/central_start_dsu_ui.html", parent_selector
        for dsu in @vm.data_dsus
            @watch_dsu_checked dsu
                
    define_vm: (vm) =>
        vm.lang = lang.dsuui
        vm.data_dsus = @_gen_dsus "data"
        vm.spare_dsus = @_gen_dsus "spare"
        vm.active_index = 0
        vm.on_quickmode = @on_quickmode
        vm.disk_checkbox_click = @disk_checkbox_click
        vm.dsu_checkbox_click = @dsu_checkbox_click
        vm.data_enabled  = 'data' in @enabled
        vm.spare_enabled = 'spare' in @enabled
        vm.disk_list = @disk_list
        
    rendered: () =>
        super()
        #console.log(@vm.data_dsus);
        $(".tooltip").attr('style', 'left:245px !important')
        
    prodsus:() =>
        tmp = []
        for i in @sd.machinedetails.items
            if i.ip in @dev.storage
                tmp.push {"location":i.dsus.location,"support_disk_nr": i.dsus.support_disk_nr,"ip":i.ip}
        tmp
       
    prodisks:() =>
        tmp = []
        for i in @sd.machinedetails.items
            for h in i.disks
                h.ip = i.ip
                tmp.push h
        tmp
        
    dsu_checkbox_click: (e) =>
        e.stopPropagation()
        
    disk_list: (disks)=>
        if disks.info == "none"
            return "空盘"
        else
            return @_translate(disks.info)
        
    _translate: (obj) =>
        status = ''
        health = {'normal':'正常', 'down':'下线', 'failed':'损坏'}
        role = {'data':'数据盘', 'spare':'热备盘', 'unused':'未使用', 'kicked':'损坏'}
        
        $.each obj, (key, val) ->
            switch key
                when 'cap_sector'
                    status += '容量: ' + fattr.cap(val)+ '<br/>'
                when 'health'
                    status += '健康: ' + health[val] + '<br/>'
                when 'role'
                    status += '状态: ' + role[val] + '<br/>'
                when 'raid'
                    if val.length > 0
                        status += '阵列: ' + val + '<br/>'
                    else
                        status += '阵列: 无'
        return status
        
    active_tab: (dsu_location) =>
        for dsu, i in @vm.data_dsus
            if dsu.location is dsu_location
                @vm.active_index = i

    disk_checkbox_click: (e) =>
        e.stopPropagation()
        #console.log($(e.target).data "location");
        location = $(e.target).data "location"
        tabid = $(e.target).data "id"
        if location
            dsutype = $(e.target).data "dsutype"
            [dsus, opp_dsus] = if dsutype is "data"\
                then [@vm.data_dsus, @vm.spare_dsus]\
                else [@vm.spare_dsus, @vm.data_dsus]
            dsu = @_find_dsu dsus, location, tabid
            #opp_dsu = @_find_dsu opp_dsus, location, tabid
            #@_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            #@_count_dsu_checked_disks opp_dsu

           ### if dsutype is "data"
                @_calculatechunk dsu
            else
                @_calculatechunk opp_dsu
            $("#dsuui").change()       ###

    watch_dsu_checked: (dsu) =>
        dsu.$watch 'checked', () =>
            for col in dsu.disks
                for disk in col
                    if not disk.avail
                        continue
                    disk.checked = dsu.checked
            #opp_dsu = @_get_opp_dsu dsu
            #@_uncheck_opp_dsu_disks dsu, opp_dsu
            @_count_dsu_checked_disks dsu
            #@_count_dsu_checked_disks opp_dsu

           # @_calculatechunk dsu
            #$("#dsuui").change()

    _calculatechunk: (dsu) =>
        @_count_dsu_checked_disks dsu
        nr = dsu.count
        if nr <= 0
            return "64KB"
        else if nr == 1
            return "256KB"
        else
            ck = 512 / (nr - 1)
            if ck > 16 and ck <= 32
                return "32KB"
            else if ck > 32 and ck <= 64
                return "64KB"
            else if ck > 64 and ck <= 128
                return "128KB"
            else if ck > 128
                return "256KB"

    getchunk:() =>
        chunk_value = []
        for dsu in @vm.data_dsus
            chunk_value.push  @_calculatechunk(dsu)
        return chunk_value[0]

    _count_dsu_checked_disks: (dsu) =>
        count = 0
        for col in dsu.disks
            for disk in col
                if disk.checked and disk.avail
                    count += 1
                    
        dsu.count = count

    _uncheck_opp_dsu_disks: (dsu, opp_dsu) =>
        try
            for col in dsu.disks
                for disk in col
                    if disk.checked
                        opp_disk = @_find_disk [opp_dsu], disk.$model.location
                        opp_disk.checked = false
        catch e
            console.log e

    get_disks: (type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        @_collect_checked_disks dsus

    _collect_checked_disks: (dsus) =>
        disks = []
        for dsu in dsus
            loc = []
            cap = []
            count = 0
            for col in dsu.disks
                for disk in col
                    if disk.checked and disk.avail
                        loc.push disk.location
                        cap.push disk.info.cap_sector
                        count = count + 1
            loc = loc.join ","
            disks.push {"ip":dsu.ip,"loc":loc,"selected":count,"cap":cap}
        return disks

    check_disks: (disks, type="data") =>
        dsus = if type is "data" then @vm.data_dsus else @vm.spare_dsus
        disks = if $.isArray(disks) then disks else [disks]
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    for checked in disks
                        if disk.location is checked.location
                            disk.checked = true
        for dsu in dsus
            @_count_dsu_checked_disks dsu

    _find_disk: (dsus, location) =>
        for dsu in dsus
            for col in dsu.disks
                for disk in col
                    if disk.$model.location is location
                        return disk

    _find_dsu: (dsus, location, id) =>
        for dsu in dsus
            if dsu.tabid is id
                for col in dsu.disks
                    for disk in col
                        if disk.$model.location is location
                            return dsu

    _get_opp_dsu: (dsu) =>
        opp_dsus = if dsu.data then @vm.spare_dsus else @vm.data_dsus
        for opp_dsu in opp_dsus
            if opp_dsu.location is dsu.location
                return opp_dsu

    _tabid: (tabid_prefix, dsu) =>
        "#{tabid_prefix}_#{dsu.ip.replace('.', '_').replace('.', '_').replace('.', '_')}"

    _gen_dsus: (prefix) =>
        return ({location: dsu.location, tabid: @_tabid(prefix, dsu), checked: false,\
            disks: @_gen_dsu_disks(dsu),ip:dsu.ip ,count: 0, data: prefix is 'data'} for dsu in @prodsus())

    _belong_to_dsu: (disk, dsu) =>
        disk.location.indexOf(dsu.location) is 0

    _update_disk_status: (location, dsu) =>
        for disk in@prodisks()
            if disk.location is location and @_belong_to_dsu(disk, dsu) and disk.raid is "" and disk.health isnt "failed" and disk.role is "unused" and disk.ip is dsu.ip
                return true
        return false
    
    _update_disk_info: (location, dsu) =>
        info = []
        for disk in @prodisks()
            if disk.location is location and @_belong_to_dsu(disk, dsu) and disk.ip is dsu.ip
                info = health:disk.health, cap_sector:disk.cap_sector, role:disk.role, raid:disk.raid
                return info

        'none'
        
    _gen_dsu_disks: (dsu) =>
        disks = []
        
        for i in [1..4]
            cols = []
            for j in [0...dsu.support_disk_nr/4]
                location = "#{dsu.location}.#{j*4+i}"
                o = location: location, avail: false, checked: false, offline: false, info: ""
                o.avail = @_update_disk_status(location, dsu)
                o.info = @_update_disk_info(location, dsu)
                cols.push o
            disks.push cols
        return disks
        
class CentralColonyChangeClientModal extends Modal
    constructor: (@sd, @page, @uuid, @name) ->
        super "central-server-modal-", "html/central_colony_change_client_modal.html"
        @_settings = new SettingsManager
        
        $(@sd.clouds).on "updated", (e, source) =>
            @vm.storages = @storages()
            
    define_vm: (vm) =>
        vm.lang = lang.central_modal
        vm.submit = @submit
        vm.ip = ""
        vm.name = @name
        vm.options_client = @options_client()
        vm.storages = @storages()
        vm.all_checked = false
        vm.$watch "all_checked", =>
            for r in vm.storages
                r.checked = vm.all_checked

    rendered: () =>
        super()
        @vm.storages = @storages()
        @vm.options_client = @options_client()
        #$("#addmachine").chosen()
        $("#add_ip").typeahead(
            source: @_settings.getUsedMachines()
            items: 6
            updater: (item) =>
                @vm.ip = item
        )
        
        $("form.create").validate(
            valid_opt(
                rules:
                    ip:
                        required: true
                        regex: /\d{1,3}(\.\d{1,3})$/
                        same:true
                messages:
                    ip:
                        required: "请输入ip地址"))
                        
    storages:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:"",cluster: "",clusterid:""
        sub = []
        sub_ip = []
        sub_client = []
        for i in arrays
            if i.clusterid is @uuid and i.devtype is "client"
                sub_client.push i.ip
            if i.clusterid is @uuid and i.ip not in sub_ip
                sub.push i
                sub_ip.push i.ip
        
        for i in sub
            if i.ip in sub_client
                i.checked = true
        sub
        
    subitems:() =>
        arrays = subitems @sd.clouds.items,id:"",uuid:"", session:"", ip:"", created:"", \
                checked:false, status:"", version:"", devtype:"", size:"",detail_closed:true,master:"",cluster: "",\
                clusterid:""
        arrays
        
    options_client: () =>
        options = [{key:'请选择',value:''}]
        ((options.push {key:i.ip,value:i.ip}) for i in @subitems() when i.devtype isnt 'client' and i.clusterid is @uuid)
        options
        
    submit: () =>
        sub = []
        for i in @vm.storages
            sub.push {"ip":i.ip,"status":i.checked}

        @page.frozen()
        chain = new Chain
        chain.chain =>
            query = new MachineRest(@sd.host).client @uuid,JSON.stringify(sub)
            query.done (data) =>
                if data.status is "success"
                    #(new MessageModal("修改客户端成功")).attach()
                else
                    (new MessageModal(lang.central_error.message(data.errcode,data.description))).attach()
        chain.chain @sd.update('all')
        @hide()
        show_chain_progress(chain, true).done =>
            @page.attach()
                    
################################################################
this.CentralColonyChangeClientModal = CentralColonyChangeClientModal
this.CentralUnmonitorProModal = CentralUnmonitorProModal
this.CentralProStartDSUUI = CentralProStartDSUUI
this.CentralProStartModal = CentralProStartModal
this.CentralProExpandModal = CentralProExpandModal
this.CentralColonyDeleteModal = CentralColonyDeleteModal
this.CentralShowServerDetailModal = CentralShowServerDetailModal
this.CentralShowStorageDetailModal = CentralShowStorageDetailModal
this.CentralCreateColonyModal = CentralCreateColonyModal
this.CentralChangeSambaModal = CentralChangeSambaModal
this.CentralCreateMachineModal = CentralCreateMachineModal
this.CentralCombineServerModal = CentralCombineServerModal
this.CentralChangeEmailModal = CentralChangeEmailModal
this.CentralUnmonitorModal = CentralUnmonitorModal
this.CentralHandleLogModal = CentralHandleLogModal
this.CentralEmailDeleteModal = CentralEmailDeleteModal
this.CentralAddEmailModal = CentralAddEmailModal
this.CentralChangeValueModal = CentralChangeValueModal
this.CentralDownloadLogModal = CentralDownloadLogModal
this.CentralManualModal = CentralManualModal
this.CentralCreateServerModal = CentralCreateServerModal
this.CentralCreateStoreModal = CentralCreateStoreModal
this.CentralCreateClientModal = CentralCreateClientModal
this.CentralStartModal = CentralStartModal
this.CentralExpandModal = CentralExpandModal
this.CentralSearchModal = CentralSearchModal
this.CentralServerCpuModal = CentralServerCpuModal
this.CentralServerCacheModal = CentralServerCacheModal
this.CentralServerMemModal = CentralServerMemModal
this.CentralStoreDetailModal = CentralStoreDetailModal
this.CentralRecordDeleteModal = CentralRecordDeleteModal
this.CentralPieModal = CentralPieModal

###############################################################
this.ConfirmModal = ConfirmModal
this.ConfirmModal_more = ConfirmModal_more
this.ConfirmModal_link = ConfirmModal_link
this.ConfirmModal_unlink = ConfirmModal_unlink
this.ConfirmModal_scan = ConfirmModal_scan
this.EthBondingModal = EthBondingModal
this.InitrCreateModal = InitrCreateModal
this.InitrDeleteModal = InitrDeleteModal
this.MessageModal = MessageModal
this.MessageModal_reboot = MessageModal_reboot
this.Modal = Modal
this.RaidCreateDSUUI = RaidCreateDSUUI
this.RaidSetDiskRoleModal = RaidSetDiskRoleModal
this.RaidCreateModal = RaidCreateModal
this.RaidDeleteModal = RaidDeleteModal
this.ResDeleteModal = ResDeleteModal
this.ServerUI = ServerUI
this.SyncDeleteModal = SyncDeleteModal
this.VolumeCreateModal = VolumeCreateModal
this.VolumeDeleteModal = VolumeDeleteModal
this.VolumeMapModal = VolumeMapModal
this.VolumeUnmapModal = VolumeUnmapModal
this.FsCreateModal = FsCreateModal
this.FsChooseModal = FsChooseModal