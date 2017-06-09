var PortletDraggable = function () {

    return {
        //main function to initiate the module
        init: function () {

            if (!jQuery().sortable) {
            	console.log();
                return;
            }
            $("#sortable_portlets").sortable({
                connectWith: ".portlet",
                items: ".portlet",
                opacity: 0.8,
                coneHelperSize: true,
                placeholder: 'sortable-box-placeholder round-all',
                forcePlaceholderSize: true,
                tolerance: "pointer"
            });

            $(".column").disableSelection();

        }

    };

}();

/* html for draggable
 * doctype html
div.container-fluid
  h3.page-title(ms-html="'系统配置'")
  div.ui-sortable.row-fluid#sortable_portlets
    div.span12.column.sortable
      div.portlet.box.purple
        div.portlet-title
          div.caption
            i.icon-layers
            | 机器列表
          div.actions
            a.btn.btn-default.btn-sm(href="javascript:;",ms-click="create_mysql")
              i.icon-plus
              | {{lang.add_btn}}
            | &nbsp;
            a.btn.btn-default.btn-sm(href="javascript:;",ms-click="delete_record")
              i.icon-trash
              | {{lang.remove_btn}}
            | &nbsp;
            
        div.portlet-body
          table#store-table.table.table-striped.table-hover
            thead
              tr
                th(style="width: 45px;")
                  input(type="checkbox",ms-duplex-radio="all_checked",id="all_checked")
                //th(ms-text="lang.th_detail",style="")
                th(ms-text="lang.th_ip",style="width: 134px;")
                th(ms-text="lang.th_session",style="width: 86px;")
                th(ms-text="lang.th_name",style="width: 77px;")
                //th(ms-text="lang.th_server",style="width: 141px;")
                th(ms-text="lang.th_edit",style="width: 80px;")
            tbody
              tr(ms-repeat-e="devices")
                td
                  input(type="checkbox",ms-duplex-radio="e.checked")
                //td
                  //span.row-details(ms-click="detail",ms-class="row-details-close:e.detail_closed",ms-class-1="row-details-open:!e.detail_closed")
                td(ms-text="e.ip")
                td(ms-html="fattr_server_health(e.status)")
                td(ms-text="e.name")
                td
                  a.btn.mini.green(href="javascript:;",ms-click="open_client(e.ip,e.devtype)",ms-if="e.status === false")
                    | 启动
                  a.btn.mini.red(href="javascript:;",ms-click="close_client(e.ip,e.devtype)",ms-if="e.status === true")
                    | 停止
 */