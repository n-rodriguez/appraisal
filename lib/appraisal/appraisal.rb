require 'appraisal/gemfile'
require 'appraisal/command'
require 'appraisal/utils'
require 'fileutils'
require 'pathname'

module Appraisal
  # Represents one appraisal and its dependencies
  class Appraisal
    attr_reader :name, :gemfile

    def initialize(name, source_gemfile)
      @name = name
      @gemfile = source_gemfile.dup
    end

    def gem(*args)
      gemfile.gem(*args)
    end

    def source(*args)
      gemfile.source(*args)
    end

    def ruby(*args)
      gemfile.ruby(*args)
    end

    def git(*args, &block)
      gemfile.git(*args, &block)
    end

    def group(*args, &block)
      gemfile.group(*args, &block)
    end

    def platforms(*args, &block)
      gemfile.platforms(*args, &block)
    end

    def gemspec(options = {})
      gemfile.gemspec(options)
    end

    def write_gemfile
      ::File.open(gemfile_path, "w") do |file|
        signature = "# This file was generated by Appraisal"
        file.puts([signature, gemfile.to_s].reject {|s| s.empty? }.join("\n\n"))
      end
    end

    def install(job_size = 1)
      Command.new(check_command + ' || ' + install_command(job_size)).run
    end

    def update(gems = [])
      Command.new(update_command(gems)).run
    end

    def gemfile_path
      unless gemfile_root.exist?
        gemfile_root.mkdir
      end

      gemfile_root.join("#{clean_name}.gemfile").to_s
    end

    def relativize
      current_directory = Pathname.new(Dir.pwd)
      relative_path = current_directory.relative_path_from(gemfile_root).cleanpath
      lockfile_content = ::File.read(lockfile_path)

      ::File.open(lockfile_path, 'w') do |file|
        file.write lockfile_content.gsub(/#{current_directory}/, relative_path.to_s)
      end
    end

    private

    def check_command
      gemfile_option = "--gemfile='#{gemfile_path}'"
      ['bundle', 'check', gemfile_option].join(' ')
    end

    def install_command(job_size)
      gemfile_option = "--gemfile='#{gemfile_path}'"
      ['bundle', 'install', gemfile_option, bundle_parallel_option(job_size)].compact.join(' ')
    end

    def update_command(gems)
      gemfile_config = "BUNDLE_GEMFILE='#{gemfile_path}'"
      [gemfile_config, 'bundle', 'update', *gems].compact.join(' ')
    end

    def gemfile_root
      Pathname.new(::File.join(Dir.pwd, "gemfiles"))
    end

    def lockfile_path
      "#{gemfile_path}.lock"
    end

    def clean_name
      name.gsub(/[^\w\.]/, '_')
    end

    def bundle_parallel_option(job_size)
      if job_size > 1
        if Utils.support_parallel_installation?
          "--jobs=#{job_size}"
        else
          warn 'Your current version of Bundler does not support parallel installation. Please ' +
            'upgrade Bundler to version >= 1.4.0, or invoke `appraisal` without `--jobs` option.'
        end
      end
    end
  end
end
