module Ohm
  class Stats
    def self.models
      models = []

      Object.constants.each do |name|
        constant = Object.const_get(name)
        models << constant if constant && constant.kind_of?(Class) && constant.ancestors.include?(Ohm::Model)
      end

      models
    end

    def to_a
      [models, memory]
    end

    def to_s
      to_a.join "\n\n"
    end

    def models
      Table.new(["", "Count", "Keys", "Keys (%)", "Keys/instance"]).tap do |table|
        self.class.models.each do |model|
          table << Stat.new(model).to_a
        end

        table << ["Keys", nil, Stat.keys, Table::Percentage.new(100)]
      end
    end

    def average_key_size
      222
    end

    def available_memory
      if File.exists?("/proc/meminfo")
        File.read("/proc/meminfo")[/MemTotal:\s*(\d+)/, 1].to_i * 1024
      else
        %x{sysctl -a}[/hw\.memsize: (\d+)/, 1].to_i
      end
    end

    def memory
      Table.new.tap do |table|
        table << ["Available memory", available_memory]
        table << ["Average key size", average_key_size]
        table << ["Maximum amount of keys", max_amount_of_keys]
      end
    end

    def max_amount_of_keys
      available_memory / average_key_size
    end

    class Stat
      def self.keys
        @@keys ||= Ohm.redis.info[:db0][/keys=(\d+)/, 1].to_i
      end

      attr :model

      def initialize(model)
        @model = model
      end

      def total
        @total ||= model.all.size
      end

      def keys
        @keys ||= Ohm.redis.keys("#{model}:*").size
      end

      def keyspace_share
        @keyspace_share ||= keys.to_f * 100 / self.class.keys
      end

      def key_instance_ratio
        @key_instance_ratio ||= keys.to_f / total.to_f
      end

      def to_a
        [model, total, keys, Table::Percentage.new(keyspace_share), Table::Float.new(key_instance_ratio)]
      end
    end

    class Sample
      include Enumerable

      def initialize(array)
        @array = array
      end

      def sum
        inject(0) { |sum, x| sum + x }
      end

      def each(&block)
        @array.each(&block)
      end

      def empty?
        @array.empty?
      end

      def size
        @array.size
      end

      def mean
        return 0.0 if empty?
        sum.to_f / size
      end

      def median
        return 0 if empty?
        tmp = sort
        mid = tmp.size / 2
        if (tmp.size % 2) == 0
          (tmp[mid-1] + tmp[mid]).to_f / 2
        else
          tmp[mid]
        end
      end

      def to_a
        [sum, Table::Float.new(mean), Table::Float.new(median)]
      end
    end

    class Table
      class Float
        def initialize(number)
          @number = number
        end

        def to_s
          "%0.2f" % @number.to_f
        end
      end

      class Percentage < Float
        def to_s
          "#{super}%"
        end
      end

      def initialize(columns = [])
        @column_sizes = Hash.new { |h, k| h[k] = 0 }
        @rows = []

        self << columns
      end

      def <<(row)
        row.each_with_index do |col, index|
          size = col.to_s.size

          @column_sizes[index] = size if size > @column_sizes[index]
        end

        @rows << row
      end

      def align_right?(value)
        case value
        when Fixnum, Float, Percentage
          true
        else
          false
        end
      end

      def to_s
        buffer = ""

        @rows[0].each_with_index do |col, index|
          if align_right?(@rows[1][index])
            buffer << col.to_s.rjust(@column_sizes[index])
          else
            buffer << col.to_s.ljust(@column_sizes[index])
          end

          buffer << "  "
        end

        buffer << "\n"

        @rows[1..-1].each do |row|
          row.each_with_index do |col, index|
            if align_right?(col)
              buffer << col.to_s.rjust(@column_sizes[index])
            else
              buffer << col.to_s.ljust(@column_sizes[index])
            end

            buffer << "  "
          end

          buffer << "\n"
        end

        buffer
      end
    end
  end
end
