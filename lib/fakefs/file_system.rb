module FakeFS
  module FileSystem
    extend self

    def dir_levels
      @dir_levels ||= []
    end

    def fs
      @fs ||= MockDir.new('.')
    end

    def clear
      @dir_levels = nil
      @fs = nil
    end

    def files
      fs.values
    end

    def find(path)
      parts = path_parts(normalize_path(path))

      target = parts[0...-1].inject(fs) do |dir, part|
        dir[part] || {}
      end

      case parts.last
      when '*'
        target.values
      else
        target[parts.last]
      end
    end

    def add(path, object=MockDir.new)
      parts = path_parts(normalize_path(path))

      d = parts[0...-1].inject(fs) do |dir, part|
        dir[part] ||= MockDir.new(part, dir)
      end

      object.name = parts.last
      object.parent = d
      d[parts.last] ||= object
    end

    # copies directories and files from the real filesystem
    # into our fake one
    def clone(path)
      path    = File.expand_path(path)
      pattern = File.join(path, '**', '*')
      files   = RealFile.file?(path) ? [path] : [path] + RealDir.glob(pattern, RealFile::FNM_DOTMATCH)

      files.each do |f|
        if RealFile.file?(f)
          FileUtils.mkdir_p(File.dirname(f))
          File.open(f, 'w') do |g|
            g.print RealFile.open(f){|h| h.read }
          end
        elsif RealFile.directory?(f)
          FileUtils.mkdir_p(f)
        elsif RealFile.symlink?(f)
          FileUtils.ln_s()
        end
      end
    end

    def delete(path)
      if dir = FileSystem.find(path)
        dir.parent.delete(dir.name)
      end
    end

    def chdir(dir, &blk)
      new_dir = find(dir)
      dir_levels.push dir if blk

      raise Errno::ENOENT, dir unless new_dir

      dir_levels.push dir if !blk
      blk.call if blk
    ensure
      dir_levels.pop if blk
    end

    def path_parts(path)
      path.split(File::PATH_SEPARATOR).reject { |part| part.empty? }
    end

    def normalize_path(path)
      if Pathname.new(path).absolute?
        File.expand_path(path)
      else
        parts = dir_levels + [path]
        File.expand_path(File.join(*parts))
      end
    end

    def current_dir
      find(normalize_path('.'))
    end
  end
end