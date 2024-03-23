
require 'zip'
require 'pandoc-ruby'

=begin
  file:
    problem
      - problem-properties.json
    statment-sections:
      - name.tex
      - input.tex
      - output.tex
      - legend.tex
      - example.01
      - example.01.a
    tests:
      - 01
      - 01.a
      - 02
      - 02.a
=end

class PolygonExtractor

  def initialize(folder_path, zip_file_path, language)
    @folder_path = folder_path
    @zip_file_path = zip_file_path
    @language = language
    @problem_propertis_regex = /^statements\/#{@language}\/problem-properties\.json/
    @statement_section_regex = /^statement-sections\/#{@language}\/(.*)/
  end


  def extract_ploygon_problem
    description = default_description
    Zip::File.open(@zip_file_path) do |zip_file|
      @zip_file = zip_file
      @zip_file.each do |entry|
        process_entry(entry,description)
      end
    end
    description
  end

  private

  def default_description
    {
      "maxOutputSize" => 0,
      "testdata_pair" => {},
      "group" => {}
    }
  end

  def process_entry(entry,description)
    case entry.name
      when /^problem.xml$/
        process_xml(entry,description)
      when /^check.cpp$/
        process_checker(entry,description)
      when /^tests\//
        process_test_files(entry,description)
      else
        process_document(entry,description)
    end
  end

  def process_xml(entry,description)
    xml = entry.get_input_stream.read.force_encoding("utf-8")
    hash = Hash.from_xml(xml)
    tests = hash["problem"]["judging"]["testset"]["tests"]
    process_tests(tests,description)
  end

  def process_tests(tests,description)
    tests["test"].each_with_index do |data,i|
      group = data["group"]
      description["group"][group] ||= {"problem index" => [], "score" => 0};
      description["group"][group]["problem index"] << i
      description["group"][group]["score"] += data["points"].to_f
    end
  end


  def process_checker(entry,description)
    checker_code = entry.get_input_stream.read.split("\n");
    is_main = false;

    main_regex = /int\s+main\s*\(\s*int\s+argc\s*,\s*char\s*\*\s*argv\[\s*\]\s*\)/
    checker_code.map! do |line|
      line = process_main(line, is_main)
      is_main = true if line =~ main_regex
      process_line(line)
    end

    description["checker"] = checker_code.join("\n")
  end

  def process_main(line,is_main)
    return line unless is_main
    line.sub(/(^\s*\{\s*|^\s*)/, '\1 char *fargv[4] = {argv[0], argv[2], argv[1], argv[3]};')
  end

  def process_line(line)
    if line =~ /quitf\s*\(\s*_ok/
      line.sub(/(^\s*\{\s*|^\s*)/, '\1 puts("0"),')
    elsif line.include?("registerTestlibCmd")
      " registerTestlibCmd(4, fargv);"
    else
      line
    end
  end


  def process_test_files(entry,description)
    match_data = entry.name.match(/^tests\/(\d+)(\.a)?$/)
    return unless match_data
    index = match_data[1].to_i
    # suffix 1 => outputfile, 0 => inputfile
    suffix = match_data[2] ? 1 : 0

    file_path = File.join(@folder_path, entry.name.split("/").last)
    @zip_file.extract(entry, file_path) unless File.exist?(file_path)

    description["testdata_pair"][index] ||= [nil,nil]
    description["testdata_pair"][index][suffix] = file_path
    update_max_output_size(file_path,description) if suffix == 1
  end

  def update_max_output_size(file_path,description)
    # max output size will be the (neareas 2^k) * 2 of the file size
    description["maxOutputSize"] = [description["maxOutputSize"], 65536, next_power_of_2(File.size(file_path))*2].max
  end

  def process_document(entry,description)
    latex_to_md = ->(latex) {
      PandocRuby.convert(latex.force_encoding("UTF-8"), :from => :latex, :to => :markdown)
     }

    if entry.name =~ @problem_propertis_regex
        puts "problem properties"
        problem_properties = JSON.parse(entry.get_input_stream.read)
        description["memoryLimit"] = problem_properties["memoryLimit"]
        description["timeLimit"] = problem_properties["timeLimit"]/1000
    end
    match = entry.name.match(@statement_section_regex)
    if match
      case match[1]
        when "name.tex"
          description["name"] = latex_to_md.call(entry.get_input_stream.read)
        when "input.tex"
          description["input"] = latex_to_md.call( entry.get_input_stream.read )
        when "output.tex"
          description["output"] = latex_to_md.call( entry.get_input_stream.read )
        when "legend.tex"
          description["legend"] = latex_to_md.call( entry.get_input_stream.read )
        when /^example\.\d+$/
          description["examplein"] ||= {}
          description["examplein"][entry.name.split(".").last.to_i] = entry.get_input_stream.read
        when /^example\.\d+\.a$/
          description["exampleout"] ||= {}
          description["exampleout"][entry.name.split(".")[-2].to_i ] = entry.get_input_stream.read
      end
    end
  end

  def next_power_of_2(number)
    return 1 if number < 1
    result = 1
    result *= 2 while result <= number
    result
  end


end
