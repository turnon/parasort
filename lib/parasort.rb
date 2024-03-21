# frozen_string_literal: true

require_relative "parasort/version"

require "fileutils"
require "xenum"

module Parasort
  class S
    attr_reader :tempdir

    ATOM_SIZE = ENV['PARASORT_ATOM_SIZE'].to_i.yield_self{ |n| n > 0 ? n : 10000 }

    def initialize(lines)
      @lines = lines
      @tempdir = File.join('/tmp', Time.now.strftime('%Y%m%d_%H%M%S'))
      @compound = Compound.new(@tempdir)
      work
    end

    def work
      FileUtils.mkdir(tempdir)

      @lines.each_slice(ATOM_SIZE).each_with_index do |ls, i|
        ls.sort!
        dest = File.join(tempdir, "#{i}_#{i}")
        File.open(dest, 'w'){ |f| f.puts ls }
        @compound.add(0, Atom.new(dest))
      end

      nil
    end
  end

  class Compound
    attr_reader :tempdir

    def initialize(tempdir)
      @tempdir = tempdir
      @compound = Hash.new{ |h, k| h[k] = [] }
    end

    def add(level, path)
      @compound[level] << path
      loop do
        level, granules = @compound.detect{ |lvl, grans| grans.count >= 128 }
        break unless level

        @compound[level + 1] << Molecule.new(tempdir, granules.dup)
        @compound[level].clear
      end
      path
    end
  end

  class Atom
    attr_reader :path, :range

    def initialize(path)
      @path = path
      @range = File.basename(@path).split('_').map(&:to_i)
    end

    def move_to_dir(dir)
      FileUtils.mv(@path, dir)
      @path = File.join(dir, File.basename(@path))
    end

    def lines
      File.foreach(@path)
    end
  end

  class Molecule
    attr_reader :path, :range

    MOLECULE_RATE = ENV['PARASORT_MOLECULE_RATE'].to_i.yield_self{ |n| n > 0 ? n : 10000 }

    def initialize(dir, files)
      @done = false
      @lock = Mutex.new
      @cond = ConditionVariable.new

      @range = files.map(&:range).flatten.minmax
      @path = File.join(dir, @range.join('_'))
      @dir = dir

      Thread.new(files.freeze) do |fs|
        @lock.synchronize do
          Process.wait(fork{ _merge(fs) })
          @done = true
          @cond.broadcast
        end
      end
    end

    def move_to_dir(dir)
      wait_for_done
      FileUtils.mv(@path, dir)
      @path = File.join(dir, File.basename(@path))
    end

    def lines
      wait_for_done
      File.foreach(@path)
    end

    private

    def wait_for_done
      loop do
        break if @done
        @lock.synchronize do
          next if @done
          @cond.wait(@lock)
        end
      end
    end

    def _merge(files)
      # move to dir
      subdir = File.join(@dir, "merging_#{@range.join('_')}")
      FileUtils.mkdir(subdir)
      files.each{ |f| f.move_to_dir(subdir) }

      # merge
      File.open(@path, 'w') do |dest|
        lineses = files.map(&:lines)
        [].merge_sort(*lineses).each_slice(MOLECULE_RATE) do |lines|
          dest.puts lines
        end
      end

      # tear down
      FileUtils.rm_rf(subdir)
    end
  end
end
