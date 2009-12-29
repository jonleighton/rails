require 'digest/md5'
require 'active_support/secure_random'
require 'rails/version' unless defined?(Rails::VERSION)

module Rails::Generators
  # We need to store the RAILS_DEV_PATH in a constant, otherwise the path
  # can change in Ruby 1.8.7 when we FileUtils.cd.
  RAILS_DEV_PATH = File.expand_path("../../../../../..", File.dirname(__FILE__))

  class AppGenerator < Base
    DATABASES = %w( mysql oracle postgresql sqlite3 frontbase ibm_db )
    add_shebang_option!

    argument :app_path, :type => :string

    class_option :database, :type => :string, :aliases => "-d", :default => "sqlite3",
                            :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

    class_option :template, :type => :string, :aliases => "-m",
                            :desc => "Path to an application template (can be a filesystem path or URL)."

    class_option :dev, :type => :boolean, :default => false,
                       :desc => "Setup the application with Gemfile pointing to your Rails checkout"

    class_option :edge, :type => :boolean, :default => false,
                        :desc => "Setup the application with Gemfile pointing to Rails repository"

    class_option :skip_activerecord, :type => :boolean, :aliases => "-O", :default => false,
                                     :desc => "Skip ActiveRecord files"

    class_option :skip_testunit, :type => :boolean, :aliases => "-T", :default => false,
                                 :desc => "Skip TestUnit files"

    class_option :skip_prototype, :type => :boolean, :aliases => "-J", :default => false,
                                  :desc => "Skip Prototype files"

    # Add bin/rails options
    class_option :version, :type => :boolean, :aliases => "-v", :group => :rails,
                           :desc => "Show Rails version number and quit"

    class_option :help, :type => :boolean, :aliases => "-h", :group => :rails,
                        :desc => "Show this help message and quit"

    def initialize(*args)
      super
      if !options[:no_activerecord] && !DATABASES.include?(options[:database])
        raise Error, "Invalid value for --database option. Supported for preconfiguration are: #{DATABASES.join(", ")}."
      end
    end

    def create_root
      self.destination_root = File.expand_path(app_path, destination_root)
      empty_directory '.'

      set_default_accessors!
      FileUtils.cd(destination_root)
    end

    def create_root_files
      copy_file "README"
      copy_file "gitignore", ".gitignore"
      template "Rakefile"
      template "config.ru"
      template "Gemfile"
    end

    def create_app_files
      directory "app"
    end

    def create_config_files
      empty_directory "config"

      inside "config" do
        template "routes.rb"
        template "application.rb"
        template "environment.rb"

        directory "environments"
        directory "initializers"
        directory "locales"
      end
    end

    def create_boot_file
      copy_file "config/boot.rb"
    end

    def create_activerecord_files
      return if options[:skip_activerecord]
      template "config/databases/#{options[:database]}.yml", "config/database.yml"
    end

    def create_db_files
      directory "db"
    end

    def create_doc_files
      directory "doc"
    end

    def create_lib_files
      empty_directory "lib"
      empty_directory "lib/tasks"
    end

    def create_log_files
      empty_directory "log"

      inside "log" do
        %w( server production development test ).each do |file|
          create_file "#{file}.log"
          chmod "#{file}.log", 0666, :verbose => false
        end
      end
    end

    def create_public_files
      directory "public", "public", :recursive => false # Do small steps, so anyone can overwrite it.
    end

    def create_public_image_files
      directory "public/images"
    end

    def create_public_stylesheets_files
      directory "public/stylesheets"
    end

    def create_prototype_files
      return if options[:skip_prototype]
      directory "public/javascripts"
    end

    def create_script_files
      directory "script" do |content|
        "#{shebang}\n" + content
      end
      chmod "script", 0755, :verbose => false
    end

    def create_test_files
      return if options[:skip_testunit]
      directory "test"
    end

    def create_tmp_files
      empty_directory "tmp"

      inside "tmp" do
        %w(sessions sockets cache pids).each do |dir|
          empty_directory dir
        end
      end
    end

    def create_vendor_files
      empty_directory "vendor/plugins"
    end

    def apply_rails_template
      apply rails_template if rails_template
    rescue Thor::Error, LoadError, Errno::ENOENT => e
      raise Error, "The template [#{rails_template}] could not be loaded. Error: #{e}"
    end

    protected

      attr_accessor :rails_template

      def set_default_accessors!
        app_name # Cache app name

        self.rails_template = case options[:template]
          when /^http:\/\//
            options[:template]
          when String
            File.expand_path(options[:template], Dir.pwd)
          else
            options[:template]
        end
      end

      # Define file as an alias to create_file for backwards compatibility.
      def file(*args, &block)
        create_file(*args, &block)
      end

      def app_name
        @app_name ||= File.basename(destination_root)
      end

      def app_const
        @app_const ||= "#{app_name.classify}::Application"
      end

      def app_secret
        ActiveSupport::SecureRandom.hex(64)
      end

      def dev_or_edge?
        options.dev? || options.edge?
      end

      def self.banner
        "#{$0} #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      def mysql_socket
        @mysql_socket ||= [
          "/tmp/mysql.sock",                        # default
          "/var/run/mysqld/mysqld.sock",            # debian/gentoo
          "/var/tmp/mysql.sock",                    # freebsd
          "/var/lib/mysql/mysql.sock",              # fedora
          "/opt/local/lib/mysql/mysql.sock",        # fedora
          "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
          "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
          "/opt/local/var/run/mysql5/mysqld.sock",  # mac + darwinports + mysql5
          "/opt/lampp/var/mysql/mysql.sock"         # xampp for linux
        ].find { |f| File.exist?(f) } unless RUBY_PLATFORM =~ /(:?mswin|mingw)/
      end
  end
end
