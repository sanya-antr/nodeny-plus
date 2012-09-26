/*
 * Configurable variables. You may need to tweak these to be compatible with
 * the server-side, but the defaults work in most cases.
 */
var hexcase = 0;  /* hex output format. 0 - lowercase; 1 - uppercase        */
var b64pad  = ""; /* base-64 pad character. "=" for strict RFC compliance   */
var chrsz   = 8;  /* bits per input character. 8 - ASCII; 16 - Unicode      */

/*
 * These are the functions you'll usually want to call
 * They take string arguments and return either hex or base-64 encoded strings
 */
function hex_md5(s){ return binl2hex(core_md5(str2binl(s), s.length * chrsz));}
function b64_md5(s){ return binl2b64(core_md5(str2binl(s), s.length * chrsz));}
function str_md5(s){ return binl2str(core_md5(str2binl(s), s.length * chrsz));}
function hex_hmac_md5(key, data) { return binl2hex(core_hmac_md5(key, data)); }
function b64_hmac_md5(key, data) { return binl2b64(core_hmac_md5(key, data)); }
function str_hmac_md5(key, data) { return binl2str(core_hmac_md5(key, data)); }

/*
 * Perform a simple self-test to see if the VM is working
 */
function md5_vm_test()
{
  return hex_md5("abc") == "900150983cd24fb0d6963f7d28e17f72";
}

/*
 * Calculate the MD5 of an array of little-endian words, and a bit length
 */
function core_md5(x, len)
{
  /* append padding */
  x[len >> 5] |= 0x80 << ((len) % 32);
  x[(((len + 64) >>> 9) << 4) + 14] = len;

  var a =  1732584193;
  var b = -271733879;
  var c = -1732584194;
  var d =  271733878;

  for(var i = 0; i < x.length; i += 16)
  {
    var olda = a;
    var oldb = b;
    var oldc = c;
    var oldd = d;

    a = md5_ff(a, b, c, d, x[i+ 0], 7 , -680876936);
    d = md5_ff(d, a, b, c, x[i+ 1], 12, -389564586);
    c = md5_ff(c, d, a, b, x[i+ 2], 17,  606105819);
    b = md5_ff(b, c, d, a, x[i+ 3], 22, -1044525330);
    a = md5_ff(a, b, c, d, x[i+ 4], 7 , -176418897);
    d = md5_ff(d, a, b, c, x[i+ 5], 12,  1200080426);
    c = md5_ff(c, d, a, b, x[i+ 6], 17, -1473231341);
    b = md5_ff(b, c, d, a, x[i+ 7], 22, -45705983);
    a = md5_ff(a, b, c, d, x[i+ 8], 7 ,  1770035416);
    d = md5_ff(d, a, b, c, x[i+ 9], 12, -1958414417);
    c = md5_ff(c, d, a, b, x[i+10], 17, -42063);
    b = md5_ff(b, c, d, a, x[i+11], 22, -1990404162);
    a = md5_ff(a, b, c, d, x[i+12], 7 ,  1804603682);
    d = md5_ff(d, a, b, c, x[i+13], 12, -40341101);
    c = md5_ff(c, d, a, b, x[i+14], 17, -1502002290);
    b = md5_ff(b, c, d, a, x[i+15], 22,  1236535329);

    a = md5_gg(a, b, c, d, x[i+ 1], 5 , -165796510);
    d = md5_gg(d, a, b, c, x[i+ 6], 9 , -1069501632);
    c = md5_gg(c, d, a, b, x[i+11], 14,  643717713);
    b = md5_gg(b, c, d, a, x[i+ 0], 20, -373897302);
    a = md5_gg(a, b, c, d, x[i+ 5], 5 , -701558691);
    d = md5_gg(d, a, b, c, x[i+10], 9 ,  38016083);
    c = md5_gg(c, d, a, b, x[i+15], 14, -660478335);
    b = md5_gg(b, c, d, a, x[i+ 4], 20, -405537848);
    a = md5_gg(a, b, c, d, x[i+ 9], 5 ,  568446438);
    d = md5_gg(d, a, b, c, x[i+14], 9 , -1019803690);
    c = md5_gg(c, d, a, b, x[i+ 3], 14, -187363961);
    b = md5_gg(b, c, d, a, x[i+ 8], 20,  1163531501);
    a = md5_gg(a, b, c, d, x[i+13], 5 , -1444681467);
    d = md5_gg(d, a, b, c, x[i+ 2], 9 , -51403784);
    c = md5_gg(c, d, a, b, x[i+ 7], 14,  1735328473);
    b = md5_gg(b, c, d, a, x[i+12], 20, -1926607734);

    a = md5_hh(a, b, c, d, x[i+ 5], 4 , -378558);
    d = md5_hh(d, a, b, c, x[i+ 8], 11, -2022574463);
    c = md5_hh(c, d, a, b, x[i+11], 16,  1839030562);
    b = md5_hh(b, c, d, a, x[i+14], 23, -35309556);
    a = md5_hh(a, b, c, d, x[i+ 1], 4 , -1530992060);
    d = md5_hh(d, a, b, c, x[i+ 4], 11,  1272893353);
    c = md5_hh(c, d, a, b, x[i+ 7], 16, -155497632);
    b = md5_hh(b, c, d, a, x[i+10], 23, -1094730640);
    a = md5_hh(a, b, c, d, x[i+13], 4 ,  681279174);
    d = md5_hh(d, a, b, c, x[i+ 0], 11, -358537222);
    c = md5_hh(c, d, a, b, x[i+ 3], 16, -722521979);
    b = md5_hh(b, c, d, a, x[i+ 6], 23,  76029189);
    a = md5_hh(a, b, c, d, x[i+ 9], 4 , -640364487);
    d = md5_hh(d, a, b, c, x[i+12], 11, -421815835);
    c = md5_hh(c, d, a, b, x[i+15], 16,  530742520);
    b = md5_hh(b, c, d, a, x[i+ 2], 23, -995338651);

    a = md5_ii(a, b, c, d, x[i+ 0], 6 , -198630844);
    d = md5_ii(d, a, b, c, x[i+ 7], 10,  1126891415);
    c = md5_ii(c, d, a, b, x[i+14], 15, -1416354905);
    b = md5_ii(b, c, d, a, x[i+ 5], 21, -57434055);
    a = md5_ii(a, b, c, d, x[i+12], 6 ,  1700485571);
    d = md5_ii(d, a, b, c, x[i+ 3], 10, -1894986606);
    c = md5_ii(c, d, a, b, x[i+10], 15, -1051523);
    b = md5_ii(b, c, d, a, x[i+ 1], 21, -2054922799);
    a = md5_ii(a, b, c, d, x[i+ 8], 6 ,  1873313359);
    d = md5_ii(d, a, b, c, x[i+15], 10, -30611744);
    c = md5_ii(c, d, a, b, x[i+ 6], 15, -1560198380);
    b = md5_ii(b, c, d, a, x[i+13], 21,  1309151649);
    a = md5_ii(a, b, c, d, x[i+ 4], 6 , -145523070);
    d = md5_ii(d, a, b, c, x[i+11], 10, -1120210379);
    c = md5_ii(c, d, a, b, x[i+ 2], 15,  718787259);
    b = md5_ii(b, c, d, a, x[i+ 9], 21, -343485551);

    a = safe_add(a, olda);
    b = safe_add(b, oldb);
    c = safe_add(c, oldc);
    d = safe_add(d, oldd);
  }
  return Array(a, b, c, d);

}

/*
 * These functions implement the four basic operations the algorithm uses.
 */
function md5_cmn(q, a, b, x, s, t)
{
  return safe_add(bit_rol(safe_add(safe_add(a, q), safe_add(x, t)), s),b);
}
function md5_ff(a, b, c, d, x, s, t)
{
  return md5_cmn((b & c) | ((~b) & d), a, b, x, s, t);
}
function md5_gg(a, b, c, d, x, s, t)
{
  return md5_cmn((b & d) | (c & (~d)), a, b, x, s, t);
}
function md5_hh(a, b, c, d, x, s, t)
{
  return md5_cmn(b ^ c ^ d, a, b, x, s, t);
}
function md5_ii(a, b, c, d, x, s, t)
{
  return md5_cmn(c ^ (b | (~d)), a, b, x, s, t);
}

/*
 * Calculate the HMAC-MD5, of a key and some data
 */
function core_hmac_md5(key, data)
{
  var bkey = str2binl(key);
  if(bkey.length > 16) bkey = core_md5(bkey, key.length * chrsz);

  var ipad = Array(16), opad = Array(16);
  for(var i = 0; i < 16; i++)
  {
    ipad[i] = bkey[i] ^ 0x36363636;
    opad[i] = bkey[i] ^ 0x5C5C5C5C;
  }

  var hash = core_md5(ipad.concat(str2binl(data)), 512 + data.length * chrsz);
  return core_md5(opad.concat(hash), 512 + 128);
}

/*
 * Add integers, wrapping at 2^32. This uses 16-bit operations internally
 * to work around bugs in some JS interpreters.
 */
function safe_add(x, y)
{
  var lsw = (x & 0xFFFF) + (y & 0xFFFF);
  var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
  return (msw << 16) | (lsw & 0xFFFF);
}

/*
 * Bitwise rotate a 32-bit number to the left.
 */
function bit_rol(num, cnt)
{
  return (num << cnt) | (num >>> (32 - cnt));
}

/*
 * Convert a string to an array of little-endian words
 * If chrsz is ASCII, characters >255 have their hi-byte silently ignored.
 */
function str2binl(str)
{
  var bin = Array();
  var mask = (1 << chrsz) - 1;
  for(var i = 0; i < str.length * chrsz; i += chrsz)
    bin[i>>5] |= (str.charCodeAt(i / chrsz) & mask) << (i%32);
  return bin;
}

/*
 * Convert an array of little-endian words to a string
 */
function binl2str(bin)
{
  var str = "";
  var mask = (1 << chrsz) - 1;
  for(var i = 0; i < bin.length * 32; i += chrsz)
    str += String.fromCharCode((bin[i>>5] >>> (i % 32)) & mask);
  return str;
}

/*
 * Convert an array of little-endian words to a hex string.
 */
function binl2hex(binarray)
{
  var hex_tab = hexcase ? "0123456789ABCDEF" : "0123456789abcdef";
  var str = "";
  for(var i = 0; i < binarray.length * 4; i++)
  {
    str += hex_tab.charAt((binarray[i>>2] >> ((i%4)*8+4)) & 0xF) +
           hex_tab.charAt((binarray[i>>2] >> ((i%4)*8  )) & 0xF);
  }
  return str;
}

/*
 * Convert an array of little-endian words to a base-64 string
 */
function binl2b64(binarray)
{
  var tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  var str = "";
  for(var i = 0; i < binarray.length * 4; i += 3)
  {
    var triplet = (((binarray[i   >> 2] >> 8 * ( i   %4)) & 0xFF) << 16)
                | (((binarray[i+1 >> 2] >> 8 * ((i+1)%4)) & 0xFF) << 8 )
                |  ((binarray[i+2 >> 2] >> 8 * ((i+2)%4)) & 0xFF);
    for(var j = 0; j < 4; j++)
    {
      if(i * 8 + j * 6 > binarray.length * 32) str += b64pad;
      else str += tab.charAt((triplet >> 6*(3-j)) & 0x3F);
    }
  }
  return str;
}



/*                              NoDeny                          */

function nody_ready()
{
    var nody = this;

    // Перемещение кнопки 'Debug' в #adm_debug
    $('#debug_href').
        removeClass('debug_href').
        click( function(){
            $('#debug').toggle();
            return false;
        }).
        prependTo('#adm_debug');
    $('#debug').click( function(e){
        if( $(e.target).is('#debug') ) $('#debug').toggle();
    });

    // modal window
    $(window).resize( function() {
        nody.winH = $(window).height();
        nody.winW = $(window).width();
        nody.docH = $(document).height();
        nody.docW = $(document).width();
        $('#modal_mask').css({ width : nody.docW, height : nody.docH });
        for( var id in {'#left_block':1, '#right_block':1 } )
        {
            var el = $(id);
            if( ! el.html() ) 
                     el.css({ width:0, padding:0 })
                else el.css({ width: Math.min(el.width(), 500) });
        }
    });
    $(window).resize();

    if( nody.winW < 1100 )
    {
        $('.resolution').addClass('low_resolution').removeClass('resolution');
    }
     else
    {
        $('.resolution').addClass('high_resolution').removeClass('resolution');
    }

    nody.modal_show = function(x, y)
    {
        $('#modal_mask').fadeTo('fast', 0.1);
        var wnd = $('#modal_window');
        wnd.show();
        if( x > 0 )
        {
            y = Math.max( 0, (wnd.height() + y) > nody.docH ? nody.docH - wnd.height() - 40 : y );
            x = Math.max( 0, (wnd.width() + x)  > nody.docW ? nody.docW - wnd.width()  - 40 : x );
            wnd.css({ left: x + 'px', top: y + 'px'});
        }
         else
        {
            wnd.css({
                width : Math.max(nody.winW - 300, 100),
                height: Math.max(nody.winH - 300, 100),
                left  : 150,
                top   : 150
            });
        }

    }
    nody.modal_close = function()
    {
        $('#modal_window').hide();
        $('#modal_mask').hide();
    }
    $('#modal_mask').click(nody.modal_close);

    $(document).on('keyup', 'body', function(event){
        if( event.keyCode == 27 && $('#modal_window').is(':visible') )
        {   // ESC key
            nody.modal_close();
        }
        return true;
    });

    // datepicker
    $('.dateinput').each( function(){
        $(this).simpleDatepicker({
            startdate: '2.1.2010'
        })
    });

    // make pretty tables
    $('table.pretty')
        .each( function()
        {
            var tbl_h = $(this).height();
            var bottom_space = $(document).height() - $(this).offset().top - tbl_h;
            if( bottom_space > tbl_h*0.4 )
            {
                $(this).height( Math.min(tbl_h+bottom_space-50, tbl_h*1.6) );
            }
        }).dblclick( function()
        {
            $(this).toggleClass('pretty_border');
        });

    nody.img_after_submit = jQuery('<img>').attr({'src':nody.img_after_submit, style:'vertical-align:middle'});

    // make pretty buttons
    $('input[type="submit"].nav_button')
    .each( function(){
        var btn = $(this);
        btn.css({ position: 'absolute', left: '-8000px', 'z-index': -1 });
        var new_btn = $('<span></span>', {text: btn.val(), 'class': 'nav_button'}).
            click( function(){
                if(new_btn.data('busy')) return;
                new_btn.data('busy',1);
                new_btn.html(nody.img_after_submit).append(' ' + nody.msg_after_submit);
                setTimeout( function(){
                    new_btn.html(btn.val());
                    new_btn.data('busy',0);
                }, 5000);
                btn.trigger('click');
            });
        btn.after(new_btn);
    });

    nody.click_pos = {};
    // make ajax urls
    nody.ajax_click = function(pos)
    {
        var link = $(this);
        var orig_title = link.html();
        link.html( nody.img_after_submit );
        setTimeout( function(){ link.html(orig_title); }, 5000 );
        if( !link.parents('#modal_window')[0] ) nody.click_pos = { x:pos.pageX, y:pos.pageY };
        $.ajax({
            url     : this.href,
            dataType: 'json',
            success : function(responseText, status) {
                    link.html(orig_title);
                    nody.ajax_response(responseText, status);
            }
        });
        return false;
    }
    $(document).on('click', 'a.ajax', nody.ajax_click);

    nody.make_ajax = function()
    {
        $('a.ajax').bind('click', nody.ajax_click);
    }

    $(document).on('submit', 'form.ajax', function(event){
        var data = {};
        $(this).find('input').each( function(){
            name = $(this).attr('name');
            if( name ) data[name] = $(this).val();
        });
        $(this).find('textarea').each( function(){
            name = $(this).attr('name');
            if( name ) data[name] = $(this).val();
        });
        $.ajax({
            url     : $(this).attr('action'),
            dataType: 'json',
            data    : data,
            success : nody.ajax_response
        });
        event.preventDefault();
    });

    var shown_modal = false;
    $(document).on('mousedown', '.modal_menu', function(event){
        shown_modal = false;
        $('.modal_menu').removeClass('modal_menu_active')
        var el = $(this);
        el.addClass('modal_menu_active');
        // right button
        var timeout = event.which == 3? 1 : 1000;
        var timeout_id = setTimeout( function(){
            shown_modal = true;
            nody.click_pos = { x: event.pageX, y: event.pageY };
            $.ajax({
                url     : el.attr('rel'),
                dataType: 'json',
                success : nody.ajax_response
            });
        }, timeout);
        el.mouseup( function(){
            clearTimeout(timeout_id);
        });
    });

    $(document).on('click', '.modal_menu', function(event){
        if( shown_modal ) event.preventDefault();
    });
    $(document).on('contextmenu', '.modal_menu', function(event){
        event.preventDefault();
    });

    $('[data-active=1]').addClass('active');


    $(document).on('click', "a[href='#show_or_hide']", function(){
        var a = $(this);
        var rel = $('.' + a.attr('rel'));
        rel.is(':visible')? a.removeClass('downed') : a.addClass('downed');
        rel.slideToggle(100);
        return false;
    });

    $(document).on('click', "a[href='#chkbox_list_all']", function() {
        var chkbox = "#" + $(this).attr('rel') + ' input:checkbox';
        var checked = $(chkbox + ':first').is(':checked');
        $(chkbox).attr('checked', !checked);
        return false;
    });

    $(document).on('click', "a[href='#chkbox_list_invert']", function() {
        var chkbox = "#" + $(this).attr('rel') + ' input:checkbox';
        $(chkbox).each( function(){ $(this).attr('checked', !$(this).is(':checked')) } );
        return false;
    });

    nody.set_field = function(name, val)
    {
        var obj = $('[name="' + name + '"]');
        obj.addClass('input_modified');
        obj.val(val);
    }

    nody.ajax = function(data)
    {
        $.ajax({
            url     : nody.script_url,
            dataType: 'json',
            data    : data,
            success : nody.ajax_response
        });
    }

    var debug_blocks_count = 0;
    
    nody.ajax_response = function( responseText, status )
    {
      for( var r in responseText )
      {
        if( responseText[r].json == 'error' )
        {
            $('#debug').prepend("<div style='text-align:center; padding:14px'>SERVER JSON ERROR</div>");
            continue;
        }

        var id      = responseText[r].id;
        var action  = responseText[r].action || 'replace';
        var data    = responseText[r].data   || '';
        var target  = responseText[r].target || '';
        var type    = responseText[r].type   || '';

        id = '#' + id;

        if( target == 'iframe' )
        {
            target = $(id).contents().find('body');
        }
         else
        {
            target = $(id);
        }

        if( type == 'style' )
        {
            $(id).attr('style', data);
            continue;
        }
        if( type == 'class' )
        {
            $(id).addClass(data);
            continue;
        }

        if( type == 'js' )
        {
            try{ eval(data); } catch(err){ console.log(data + '||| ' +err); }
            continue;
        }

        if( action == 'redirect' )
        {
            window.location.href = data;
            continue;
        }

        if( id == '#debug' && debug_blocks_count++ > 7 )
        {
            $(id).html('[NoDeny JS] clear debug area');
            debug_blocks_count = 0;
        }

        if( action == 'add' )
        {
            target.append(data);
        }
         else if( action == 'insert' )
        {
            target.prepend(data);
        }
         else if( action == 'value' )
        {
            target.val(data);
        }
         else
        {
            target.html(data);
        }

        if( id == '#modal_window' )
        {
            if( target.html() == '' )
            {
                nody.modal_close();
                continue;
            }
            if( action == 'replace' )
            {
                var close_button = $("<a href='#' id='modal_close'></a>").
                    click( nody.modal_close );
                target.prepend( close_button );
            }
            var x = responseText[r].x || nody.click_pos.x;
            var y = responseText[r].y || nody.click_pos.y;
            nody.modal_show( x, y );
        }
      }
    }
}

function show_or_hide(id)
{
    $('#'+id).toggle();
}

function SetAllCheckbox(id,x)
{
 var obj = document.getElementById(id).getElementsByTagName('input');
 for( var i = 0; i < obj.length; i++ )
 {
    if (obj[i].type=='checkbox') obj[i].checked = x==1?true:false;
 }
}

