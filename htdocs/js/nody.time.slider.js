(function($)
{
    var TimeSlider = function(el, options)
    {
        var obj = this;
        var max_time = 24*60;

        obj.parent = el;
        obj.value = 0;
        obj.busy = false;

        var sliderline_width = 1;
        var sliderline_left = 0;

        var container   = $('<div></div>', { 'class':'nody-timeslider-container' });
        var dash_line   = $('<div></div>', { 'class':'nody-timeslider-dashline' });
        var text_line   = $('<div></div>', { 'class':'nody-timeslider-textline' });
        var slider_line = $('<div></div>', { 'class':'nody-timeslider-sliderline' });
        var slider      = $('<div></div>', { 'class':'nody-timeslider-slider' });

        slider_line.append( slider );
        container.append( slider_line, dash_line, text_line );
        el.append( container );

        // Штрихи времени с подписями
        for( var hour = 1; hour <= 23; hour++ )
        {
            var cls = 'nody-hour-' + hour;
            var dash = $('<b></b>', { 'class': cls });
            var dashtext = $('<b></b>', { 'class': cls, text: hour });
            dash_line.append( dash );
            text_line.append( dashtext );
        }

        // При изменении размеров окна перересуем штрихи времени
        $(window).resize( function()
        {
            sliderline_width = slider_line.width() || 1;
            sliderline_left = slider_line.offset().left;
            dash_line.width(sliderline_width);
            text_line.width(sliderline_width);
            for( var hour = 1; hour <= 23; hour++ )
            {
                x = hour * sliderline_width/24 + sliderline_left;
                var cls = '.nody-hour-' + hour;
                dash_line.find(cls).offset({ left: x });
                text_line.find(cls).each( function(){
                    $(this).offset({ left: x - $(this).width()/2 })
                });
            }
            obj.update();
        });

        // Перерисовка слайдера
        obj.update = function()
        {
            // количество пикселей в минуте
            var x = sliderline_width / max_time;
            slider.offset({ left: obj.value * x + sliderline_left });
            slider.width( Math.max(3,x) );
        }

        var busy_timeout_id;
        obj.tobusy = function(timeout)
        {
            if( obj.busy ) obj.unbusy();
            obj.busy = true;
            slider.addClass('nody-timeslider-slider-busy');
            busy_timeout_id = setTimeout(
                function()
                {
                    obj.unbusy();
                },
                (timeout || 10)*1000
            );
        }

        obj.unbusy = function()
        {
            slider.removeClass('nody-timeslider-slider-busy');
            if( busy_timeout_id )
            {
                clearTimeout(busy_timeout_id);
                busy_timeout_id = null;
            }
            obj.busy = false;
        }

        obj.set_value = function( minutes )
        {
            obj.value = minutes;
            obj.update();
        };

        obj.set_hh_mm = function( hh_mm )
        {
            var m = hh_mm.match(/^(\d+)\:(\d+)/);
            if( m !== null )
            {
                obj.set_value( parseInt(m[1]*60,10) + parseInt(m[2],10) );
            }
        };

        var mouse_down = false;
        obj.mouse = function(event)
        {
            if( ! mouse_down ) return;
            var x = event.pageX - sliderline_left;
            obj.set_value( Math.round( x * max_time / sliderline_width ) );
            event.preventDefault();
        };

        container.
          mousedown( function(event)
        {
            mouse_down = true;
            obj.mouse(event)
        }).
          mousemove( function(event)
        {
            obj.mouse(event)
        }).
          mouseup( function(event)
        {
            mouse_down = false;
        });

        $(window).resize();
    }

    $.fn.timeslider = function(options)
    {
        var options = jQuery.extend({
        //    arrow_width : 5
        },options);

        return new TimeSlider($(this), options);
    }

})(jQuery);

