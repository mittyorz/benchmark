#!/usr/bin/env ruby

require 'optparse'

opt = OptionParser.new
opt.on('-i [max|avg]', 'output max or average only of results from multiple tests') {|v| v }
opt.on('-d', '--details', 'output IOPS and latency in addition to bandwidth_mb to csv')  {|v| v }
opt.on('-s', '--use_si', 'use base-10 unit (SI standard) for calculation instead of base-2 unit')  {|v| v }
opt.banner = "Usage: fio-cdm-csv.rb [options] path/to/logfile [logfile2] ..."

option = {}
opt.parse!(ARGV, into: option)


if ARGV.empty? then
  puts opt.help
  puts
  puts "This script cannot handle cases where the job name is different for each file or the order of the job is different."
  exit 0
end

fio_results = [
### data structure sample
### https://fio.readthedocs.io/en/latest/fio_doc.html#terse-output
#  {
#    :filename => 'argv[index]',
#    :job_results => {
#      "Seq-Read" => [
#        {
#            :terse_version_3 => "3",
#            :fio_version     => "fio-3.36",
#            :jobname         => "Seq-Read",
#            # ...
#        },
#      ],
#      "Seq-Write" => [
#        {
#          :terse_version_3 => "3",
#          :fio_version     => "fio-3.36",
#          :jobname         => "Seq-Write",
#          # ...
#        },
#        {
#          :terse_version_3 => "3",
#          :fio_version     => "fio-3.36",
#          :jobname         => "Seq-Write",
#          # ...
#        },
#      ],
#    },
#  },
]

fieldnames = %i[
  terse_version_3 fio_version jobname groupid error read_kb read_bandwidth_kb read_iops read_runtime_ms read_slat_min_us
  read_slat_max_us read_slat_mean_us read_slat_dev_us read_clat_min_us read_clat_max_us read_clat_mean_us read_clat_dev_us read_clat_pct01 read_clat_pct02 read_clat_pct03
  read_clat_pct04 read_clat_pct05 read_clat_pct06 read_clat_pct07 read_clat_pct08 read_clat_pct09 read_clat_pct10 read_clat_pct11 read_clat_pct12 read_clat_pct13
  read_clat_pct14 read_clat_pct15 read_clat_pct16 read_clat_pct17 read_clat_pct18 read_clat_pct19 read_clat_pct20 read_tlat_min_us read_lat_max_us read_lat_mean_us
  read_lat_dev_us read_bw_min_kb read_bw_max_kb read_bw_agg_pct read_bw_mean_kb read_bw_dev_kb write_kb write_bandwidth_kb write_iops write_runtime_ms
  write_slat_min_us write_slat_max_us write_slat_mean_us write_slat_dev_us write_clat_min_us write_clat_max_us write_clat_mean_us write_clat_dev_us write_clat_pct01 write_clat_pct02
  write_clat_pct03 write_clat_pct04 write_clat_pct05 write_clat_pct06 write_clat_pct07 write_clat_pct08 write_clat_pct09 write_clat_pct10 write_clat_pct11 write_clat_pct12
  write_clat_pct13 write_clat_pct14 write_clat_pct15 write_clat_pct16 write_clat_pct17 write_clat_pct18 write_clat_pct19 write_clat_pct20 write_tlat_min_us write_lat_max_us
  write_lat_mean_us write_lat_dev_us write_bw_min_kb write_bw_max_kb write_bw_agg_pct write_bw_mean_kb write_bw_dev_kb cpu_user cpu_sys cpu_csw
  cpu_mjf cpu_minf iodepth_1 iodepth_2 iodepth_4 iodepth_8 iodepth_16 iodepth_32 iodepth_64 lat_2us
  lat_4us lat_10us lat_20us lat_50us lat_100us lat_250us lat_500us lat_750us lat_1000us lat_2ms
  lat_4ms lat_10ms lat_20ms lat_50ms lat_100ms lat_250ms lat_500ms lat_750ms lat_1000ms lat_2000ms
  lat_over_2000ms disk_name disk_read_iops disk_write_iops disk_read_merges disk_write_merges disk_read_ticks write_ticks disk_queue_time disk_util
].freeze

ARGV.each do |filename|
  file = File.open(filename)
  job_results = {}
  file.each_line(chomp: true) do |line|
    if line =~ /^3;fio-3/ then
      data = line.split(';')
      jobname = data[2]
      results = Hash[fieldnames.zip(data)]
      if job_results.key?(jobname) then
        job_results[jobname] << results
      else
        job_results[jobname] = [results]
      end
    end 
  end
  if ! job_results.empty?
    fio_results << {
      :filename   => filename,
      :job_results => job_results,
    }
  end
end

if fio_results.empty? then
  exit
end


if option[:use_si] then
  bw_units = "MB/s(10^6)"
else
  bw_units = "MiB/s"
end
if option[:details] then
  job_header = "#{bw_units},IOPS,us"
else
  job_header = "#{bw_units}"
end

print "filename,"
if option[:details] then
  sep=",,,"
else
  sep=","
end
print fio_results[0][:job_results].keys.join(sep)
print ",," if option[:details]
print "\n"

print ","
print ([job_header] * fio_results[0][:job_results].keys.length).join(",")
print "\n"

fio_results.each do |result|
  filename=  result[:filename]
  bandwidth_mb = []
  iops = []
  latency = []
  result[:job_results].each_value.map do |results|
    read_bandwidth_kb  = results.map {|x| x[:read_bandwidth_kb]}
    read_iops          = results.map {|x| x[:read_iops]}
    read_clat_mean_us  = results.map {|x| x[:read_clat_mean_us]}
    write_bandwidth_kb = results.map {|x| x[:write_bandwidth_kb]}
    write_iops         = results.map {|x| x[:write_iops]}
    write_clat_mean_us = results.map {|x| x[:write_clat_mean_us]}

    bandwidth_mb << read_bandwidth_kb.zip(write_bandwidth_kb).map do |r,w|
      rw = r.to_i + w.to_i
      if option[:use_si] then
        # convert KiB to MB (10^6)
        rw * 1024.0 / 1000.0 / 1000.0
      else
        # convert KiB to MiB (2^20)
        rw / 1024.0
      end
    end
    iops << read_iops.zip(write_iops).map do |r,w|
      rw = r.to_i + w.to_i
    end 
    latency << read_clat_mean_us.zip(write_clat_mean_us).map do |r,w|
      rw = r.to_f + w.to_f
    end
  end

  if option[:i] == "max" then
    bandwidth_mb = bandwidth_mb.map {|x| [x.max]}
    iops         = iops.map         {|x| [x.max]}
    latency      = latency.map      {|x| [x.max]}
  elsif option[:i] == "avg" then
    bandwidth_mb = bandwidth_mb.map {|x| [x.sum(0.0) / x.length]}
    iops         = iops.map         {|x| [x.sum(0.0) / x.length]}
    latency      = latency.map      {|x| [x.sum(0.0) / x.length]}
  end

  bandwidth_mb[0].length.times do |i|
    outputs = []
    outputs << filename
    bandwidth_mb.length.times do |j|
      outputs << bandwidth_mb[j][i]
      if option[:details] then
        outputs << iops[j][i]
        outputs << latency[j][i]
      end
    end
    print outputs.join(",")
    print "\n"
  end
end
