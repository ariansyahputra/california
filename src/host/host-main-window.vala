/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * Primary application window.
 */

public class MainWindow : Gtk.ApplicationWindow {
    private View.Controllable current_view;
    private View.Month.Controllable month_view = new View.Month.Controllable();
    
    public MainWindow(Application app) {
        Object (application: app);
        
        title = Application.TITLE;
        set_size_request(800, 600);
        set_default_size(1024, 768);
        set_default_icon_name(Application.ICON_NAME);
        
        // start in Month view
        current_view = month_view;
        
        // create GtkHeaderBar and pack it in
        Gtk.HeaderBar headerbar = new Gtk.HeaderBar();
        
        Gtk.Button today = new Gtk.Button.with_label(_("Today"));
        today.clicked.connect(() => { current_view.today(); });
        
        Gtk.Button prev = new Gtk.Button.from_icon_name("go-previous-symbolic", Gtk.IconSize.MENU);
        prev.clicked.connect(() => { current_view.prev(); });
        
        Gtk.Button next = new Gtk.Button.from_icon_name("go-next-symbolic", Gtk.IconSize.MENU);
        next.clicked.connect(() => { current_view.next(); });
        
        Gtk.Box nav_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        nav_buttons.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        nav_buttons.get_style_context().add_class(Gtk.STYLE_CLASS_RAISED);
        nav_buttons.pack_start(prev);
        nav_buttons.pack_end(next);
        
        // pack left-side of window
        headerbar.pack_start(today);
        headerbar.pack_start(nav_buttons);
        
        Gtk.Button new_event = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.MENU);
        new_event.tooltip_text = _("Create a new event for today");
        new_event.clicked.connect(on_new_event);
        
        // pack right-side of window
        headerbar.pack_end(new_event);
        
        Gtk.Box layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        layout.pack_start(headerbar, false, true, 0);
        layout.pack_end(month_view, true, true, 0);
        
        // current host bindings and signals
        current_view.request_create_event.connect(on_request_create_event);
        current_view.request_display_event.connect(on_request_display_event);
        current_view.bind_property(View.Controllable.PROP_CURRENT_LABEL, headerbar, "title",
            BindingFlags.SYNC_CREATE);
        current_view.bind_property(View.Controllable.PROP_IS_VIEWING_TODAY, today, "sensitive",
            BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
        
        add(layout);
    }
    
    // Creates and shows a Gtk.Popover.
    private Gtk.Popover show_popover(Gtk.Widget relative_to, Gdk.Point? for_location,
        Gtk.Widget child) {
        Gtk.Popover popover = new Gtk.Popover(relative_to);
        if (for_location != null) {
            popover.pointing_to = Cairo.RectangleInt() { x = for_location.x, y = for_location.y,
                width = 1, height = 1 };
        }
        popover.add(child);
        
        popover.show_all();
        
        return popover;
    }
    
    private void on_new_event() {
        // start today and now, 1-hour event default
        Calendar.ExactTime dtstart = Calendar.now();
        Calendar.ExactTimeSpan dtspan = new Calendar.ExactTimeSpan(dtstart,
            dtstart.adjust_time(1, Calendar.TimeUnit.HOUR));
        
        // revert to today's date and use the widget for the popover
        Gtk.Widget widget = current_view.today();
        
        on_request_create_event(dtspan, widget, null);
    }
    
    private void on_request_create_event(Calendar.ExactTimeSpan initial, Gtk.Widget relative_to,
        Gdk.Point? for_location) {
        CreateEvent create_event = new CreateEvent(initial);
        Gtk.Popover popover = show_popover(relative_to, for_location, create_event);
        
        // when the new event is ready, that's what needs to be created
        create_event.notify[CreateEvent.PROP_NEW_EVENT].connect(() => {
            popover.destroy();
            
            if (create_event.new_event != null && create_event.calendar_source != null)
                create_event_async.begin(create_event.calendar_source, create_event.new_event, null);
        });
    }
    
    private async void create_event_async(Backing.CalendarSource calendar_source, Component.Blank new_event,
        Cancellable? cancellable) {
        try {
            yield calendar_source.create_component_async(new_event, cancellable);
        } catch (Error err) {
            debug("Unable to create event: %s", err.message);
        }
    }
    
    private void on_request_display_event(Component.Event event, Gtk.Widget relative_to,
        Gdk.Point? for_location) {
        ShowEvent show_event = new ShowEvent(event);
        Gtk.Popover popover = show_popover(relative_to, for_location, show_event);
        
        show_event.remove_event.connect(() => {
            popover.destroy();
            remove_event_async.begin(event, null);
        });
    }
    
    private async void remove_event_async(Component.Event event, Cancellable? cancellable) {
        try {
            yield event.calendar_source.remove_component_async(event.uid, cancellable);
        } catch (Error err) {
            debug("Unable to destroy event: %s", err.message);
        }
    }
}

}

