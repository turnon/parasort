# frozen_string_literal: true

require_relative "parasort/version"

require "fileutils"
require "xenum"

module Parasort
  class << self
    def each(lines, &block)
      tempdir = File.join('/tmp', Time.now.strftime('%Y%m%d_%H%M%S'))
      FileUtils.mkdir(tempdir)

      compound = Compound.new(tempdir)
      lines.each_slice(Atom::SIZE).each_with_index do |ls, i|
        ls.sort!
        dest = File.join(tempdir, "#{i}_#{i}")
        File.open(dest, 'w'){ |f| f.puts ls }
        compound.add(0, Atom.new(dest))
      end
      compound.pack!

      compound.each(&block)
    end
  end

  class Compound
    include Enumerable

    attr_reader :tempdir

    GRANULES_COUNT = 128

    def initialize(tempdir)
      @tempdir = tempdir
      @compound = Hash.new{ |h, k| h[k] = [] }
      pid = Process.pid
      at_exit{ FileUtils.rm_rf(tempdir) if pid == Process.pid }
    end

    def add(level, path)
      @compound[level] << path
      loop do
        level, granules = @compound.detect{ |lvl, grans| grans.count >= GRANULES_COUNT }
        break unless level

        @compound[level + 1] << Molecule.new(tempdir, granules.dup)
        @compound[level].clear
      end
      path
    end

    def pack!
      loop do
        break if @compound.each_value.map(&:count).sum <= GRANULES_COUNT

        level, granules = @compound.detect{ |lvl, grans| !grans.empty? }
        break unless level

        @compound[level + 1] << Molecule.new(tempdir, granules.dup)
        @compound[level].clear
      end
    end

    def each(&block)
      [].merge_sort(*@compound.flat_map{ |lvl, grans| grans.map(&:each) }).each(&block)
    end
  end

  class Atom
    attr_reader :path, :range

    SIZE = ENV['PARASORT_ATOM_SIZE'].to_i.yield_self{ |n| n > 0 ? n : 10000 }

    def initialize(path)
      @path = path
      @range = File.basename(@path).split('_').map(&:to_i)
    end

    def move_to_dir(dir)
      FileUtils.mv(@path, dir)
      @path = File.join(dir, File.basename(@path))
    end

    def each(&block)
      File.foreach(@path, &block)
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

    def each(&block)
      wait_for_done
      File.foreach(@path, &block)
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
        lineses = files.map(&:each)
        [].merge_sort(*lineses).each_slice(MOLECULE_RATE) do |lines|
          dest.puts lines
        end
      end

      # tear down
      FileUtils.rm_rf(subdir)
    end
  end
end
