motion_require './helpers/has_authorization'
module MotionPrime
  class BaseAppDelegate
    include MotionPrime::HasAuthorization

    attr_accessor :window, :sidebar_container

    def application(application, didFinishLaunchingWithOptions:launch_options)
      on_load(application, launch_options)
      true
    end

    def app_delegate
      UIApplication.sharedApplication.delegate
    end

    def app_window
      self.app_delegate.window
    end

    def open_root_screen(screen)
      screen.send(:on_screen_load) if screen.respond_to?(:on_screen_load)
      screen = screen.main_controller if screen.respond_to?(:main_controller)

      self.window ||= UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
      self.window.rootViewController = screen
      self.window.makeKeyAndVisible
      screen
    end

    def open_screen(screen)
      if sidebar?
        sidebar_container.content_controller = screen
      else
        open_root_screen(screen)
      end
    end

    def sidebar?
      !sidebar_container.nil?
    end

    def open_with_sidebar(content, menu, options={})
      self.sidebar_container = SidebarContainerScreen.new(menu, content, options)
      open_root_screen(sidebar_container)
    end

    def show_sidebar
      sidebar_container.show_sidebar
    end

    def hide_sidebar
      sidebar_container.hide_sidebar
    end
  end
end