require 'middleman-core'

module Middleman
  module Sync
    class Extension < Middleman::Extension
      option :verbose, nil, 'turn on verbose logging (defaults to false)'
      option :force, nil, 'force syncing of outdated_files (defaults to false)'
      option :run_on_build, nil, 'when within a framework which `builds` assets, whether to sync afterwards (defaults to true)'
      option :sync_outdated_files, nil, 'when an outdated file is found whether to replace it (defaults to true)'
      option :delete_abandoned_files, nil, 'when an abondoned file is found whether to remove it (defaults to true)'
      option :upload_missing_files, nil, 'when a missing file is found whether to upload it (defaults to true)'
      option :target_pool_size, nil, "how many threads you would like to open for each target (defaults to the amount of CPU core's your machine has)'"
      option :max_sync_attempts, nil, 'how many times a file should be retried if there was an error during sync (defaults to 3)'

      DEPRECATED_ASSET_SYNC_CREDENTIAL_OPTIONS = [:aws_access_key_id, :aws_secret_access_key, :rackspace_username, :rackspace_api_key, :rackspace_auth_url, :google_storage_access_key_id, :google_storage_secret_access_key, :path_style]
      DEPRECATED_ASSET_SYNC_OPTIONS = [:fog_provider, :fog_directory, :fog_region, :existing_remote_files, :gzip_compression, :after_build]
      DEPRECATED_OPTIONS = DEPRECATED_ASSET_SYNC_CREDENTIAL_OPTIONS | DEPRECATED_ASSET_SYNC_OPTIONS
      DEPRECATED_OPTIONS.each do |option_name|
        send(:option, option_name, nil)
      end

      def initialize(app, options_hash = {}, &block)
        super

        # prevent running unless in the :build environment
        return unless app.environment == :build

        require 'multi_sync' unless defined?(MultiSync)

        opts = options.dup.to_h
        opts.delete_if { |k, v| v.nil? }

        app.after_configuration do

          if DEPRECATED_OPTIONS.any? { |deprecated_option| opts.key?(deprecated_option) }
            MultiSync.warn 'Deprecated :sync options detected...'
            MultiSync.warn ':gzip_compression no longer supported' unless opts[:gzip_compression].nil?

            credentials = {}
            credentials[:region] = opts[:fog_region] unless opts[:fog_region].nil?
            DEPRECATED_ASSET_SYNC_CREDENTIAL_OPTIONS.each do |option|
              credentials[option] = opts[option] unless opts[option].nil?
            end

            MultiSync.target(:assets,
              type: opts[:fog_provider],
              target_dir: opts[:fog_directory],
              credentials: credentials
            )

            MultiSync.source(:middleman,
              type: :local,
              source_dir: MultiSync::Extensions::Middleman.source_dir
            )

            MultiSync.run_on_build = opts[:after_build] unless opts[:after_build].nil?

            case opts[:existing_remote_files]
            when 'delete'
              MultiSync.delete_abandoned_files = true
            when 'keep'
              MultiSync.delete_abandoned_files = false
            when 'ignore'
              MultiSync.delete_abandoned_files = false
            end

          end

          DEPRECATED_OPTIONS.each do |option_name|
            opts.delete(option_name)
          end

          opts.each do |key, value|
            MultiSync.send("#{key}=", value) unless value.nil?
          end
        end

        app.after_build do |builder|
          MultiSync.logger = Middleman::Cli::Build.shared_instance.logger
          MultiSync.status_logger = builder
          MultiSync.run if MultiSync.run_on_build
        end
      end
      alias_method :included, :initialize
    end

    class SourceExtension < Middleman::Extension
      self.supports_multiple_instances = true

      option :name, nil, ''
      option :type, nil, ''
      option :source_dir, nil, ''
      option :resource_options, nil, ''
      option :targets, nil, ''
      option :include, nil, ''
      option :exclude, nil, ''

      def initialize(app, options_hash = {}, &block)
        super

        # prevent running unless in the :build environment
        return unless app.environment == :build

        require 'multi_sync' unless defined?(MultiSync)

        opts = options.dup.to_h
        opts.delete_if { |k, v| v.nil? }

        app.after_configuration do
          MultiSync.source(opts.delete(:name), opts)
        end
      end
      alias_method :included, :initialize
    end

    class TargetExtension < Middleman::Extension
      self.supports_multiple_instances = true

      option :name, nil, ''
      option :type, nil, ''
      option :target_dir, nil, ''
      option :destination_dir, nil, ''
      option :credentials, nil, ''

      def initialize(app, options_hash = {}, &block)
        super

        # prevent running unless in the :build environment
        return unless app.environment == :build

        require 'multi_sync' unless defined?(MultiSync)

        opts = options.dup.to_h
        opts.delete_if { |k, v| v.nil? }

        app.after_configuration do
          MultiSync.target(opts.delete(:name), opts)
        end
      end
      alias_method :included, :initialize
    end
  end
end
