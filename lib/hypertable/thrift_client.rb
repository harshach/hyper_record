# include path hack
$:.push(File.dirname(__FILE__) + '/gen-rb')

require 'thrift'
require 'thrift/protocol/binary_protocol_accelerated'
require 'hql_service'
require File.dirname(__FILE__) + '/thrift_transport_monkey_patch'

module Hypertable
  class ThriftClient < ThriftGen::HqlService::Client
    def initialize(host, port = 38080, timeout_ms = 20000, do_open = true)
      socket = Thrift::Socket.new(host, port, timeout_ms)
      @transport = Thrift::FramedTransport.new(socket)
      protocol = Thrift::BinaryProtocolAccelerated.new(@transport)
      super(protocol)
      open() if do_open
    end

    def open()
      @transport.open()
      @do_close = true
    end

    def close()
      @transport.close() if @do_close
    end

    # more convenience methods

    def with_scanner(table, scan_spec)
      scanner = open_scanner(table, scan_spec, true)
      begin
        yield scanner
      ensure
        close_scanner(scanner)
      end
    end

    def with_mutator(table, flags=0, flush_interval=0)
      mutator = open_mutator(table, flags, flush_interval);
      begin
        yield mutator
      ensure
        close_mutator(mutator, 0)
      end
    end

    # scanner iterator
    def each_cell(scanner)
      cells = next_cells(scanner);

      while (cells.size > 0)
        cells.each {|cell| yield cell}
        cells = next_cells(scanner);
      end
    end

    def each_cell_as_arrays(scanner)
      cells = next_cells_as_arrays(scanner);

      while (cells.size > 0)
        cells.each {|cell| yield cell}
        cells = next_cells_as_arrays(scanner);
      end
    end

    def each_row(scanner)
      row = next_row(scanner);

      while (row && row.size > 0)
        yield row
        row = next_row(scanner);
      end
    end

    def each_row_as_arrays(scanner)
      row = next_row_as_arrays(scanner);

      while (row && row.size > 0)
        yield row
        row = next_row_as_arrays(scanner);
      end
    end
  end

  def self.with_thrift_client(host, port, timeout_ms = 20000)
    client = ThriftClient.new(host, port, timeout_ms)
    begin
      yield client
    ensure
      client.close()
    end
  end
end
