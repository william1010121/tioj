class ProblemFormatTransformer

  FILE_LIMIT = 5 * 1024 * 1024 * 1024
  require 'pandoc-ruby'
  require Rails.root.join('lib', 'services', 'polygon_extractor')
  def initialize(problem,file, language)
    @problem = problem
    set_base_problem

    @file= file
    @language = language
  end



  # zjson => zerojudge
  def extract_zerojudge_problem(zipped_file, folder_path)

    begin

      Zip::File.open_buffer(zipped_file.read) do |zip_file|

        assert(zip_file.size== 1, "The zip file should only contain one file")
        assert(zip_file.first.get_input_stream.read.length < FILE_LIMIT, "The file size should be less than 5GiB")
        entry = zip_file.first
        return JSON.parse(entry.get_input_stream.read)
      end
    rescue ArgumentError => e
      raise ArgumentError.new(e.message)
    rescue StandardError => e
      raise ArgumentError.new("The file is not a valid zip file")
    end
  end



  # zjson => zerojudge
  def transform_zerojudge_to_params(folder_path, zipjson = @file, language = @language)
    check_file_size
=begin
    {
    "title": "1",
    "samplecode": "8",
    "problemid": "b111",
    "display": "practice",
    "difficulty": 0,
    "backgrounds": "[]",
    "keywords": "[]",
    "sortable": "",
    "scores": [100],
    "timelimits": [1.0],
    "hint": "<div id=\"MathJax_Message\" style=\"display: none;\">&nbsp;</div>\r\n<p>7</p>",
    "specialjudge_language": {
        "suffix": "python",
        "name": "PYTHON"
    },
    "inserttime": "2024-03-23 13:08:43.0",
    "memorylimit": 64,
    "sampleinput": "5",
    "sampleoutput": "6",
    "theinput": "<div id=\"MathJax_Message\" style=\"display: none;\">&nbsp;</div>\r\n<p>3</p>",
    "theoutput": "<div id=\"MathJax_Message\" style=\"display: none;\">&nbsp;</div>\r\n<p>4</p>",
    "updatetime": "2024-03-23 13:09:40.46",
    "testfilelength": 1,
    "judgemode": "Tolerant",
    "specialjudge_code": "",
    "author": "william1010121",
    "errmsg_visible": 1,
    "problemimages": [],
    "testinfiles": ["Upload Infile data!!\n"],
    "testoutfiles": ["Upload Outfile data!!\n"],
    "comment": "9",
    "reference": "[]",
    "locale": "zh_TW",
    "language": "C",
    "content": "<div id=\"MathJax_Message\" style=\"display: none;\">&nbsp;</div>\r\n<p>2</p>"
}
    visible state open=>public, practice=>contest, hide=>invisible
=end
    json = extract_zerojudge_problem(zipjson,folder_path);
    json = filter_json_by_keys(json, zjson_permit_key)
    json["display"] =
      case json["display"]
        when "open"       "public"
        when "practice"   "contest"
        when "hide"       "invisible"
        else "public"
        end

    @problem.name = json["title"]
    @problem.tag_list = json["backgrounds"]
    @problem.solution_tag_list = json["keywords"]
    @problem.visible_state = json["display"]
    @problem.description = json["content"]
    @problem.input = json["theinput"]
    @problem.output = json["theoutput"]
    @problem.hint = json["hint"]
    @problem.source = json["author"] + "\nInsert time:#{json["inserttime"]}\n" + "Update time:#{json["updatetime"]}"
    # c++ => 2 #python =>11
    #binding.remote_pry
    if json["judgemode"] == "Special"
      @problem.specjudge_type = "zj"
      @problem.sjcode = json["specialjudge_code"]
      @problem.specjudge_compiler_id = ( json["specialjudge_language"]["suffix"] == "cpp" ? 2 : 11)
    end


    @problem.sample_testdata.build(
      input: json["sampleinput"],
      output: json["sampleoutput"]
    );

    json["scores"].each_with_index do |score,i|
      @problem.subtasks.build(
        td_list: i,
        constraints: "",
        score: score
      );
    end


    assert(json["testinfiles"].length == json["testoutfiles"].length && json["testinfiles"].length == json["timelimits"].length,
          "The length of testinfiles and testoutfiles and timelimits should be the same")
    json['td_pairs'] = json["testinfiles"].zip(json["testoutfiles"], json["timelimits"])

    json["td_pairs"].each_with_index do |td_pair, i|
      testinfile, testoutfile, timelimit = td_pair
      inputfile_path = "#{folder_path}/testinfiles#{i}.in"
      outputfile_path = "#{folder_path}/testoutfiles#{i}.out"
      inputfile = File.open(inputfile_path, "w")
      outputfile = File.open(outputfile_path, "w")
      inputfile.write(testinfile)
      outputfile.write(testoutfile)

      @problem.testdata.build(
        test_input: inputfile,
        test_output: outputfile,
        time_limit: timelimit*1000,
        rss_limit: json["memorylimit"]*1024,
        output_limit: [next_power_of_2(File.size(outputfile_path)), 65536].max
      );
    end

    return nil
  end

  def remove_folder(folder_path)
    FileUtils.rm_rf(folder_path)
  end

  def count_file_in_folder(folder_path)
    Dir.glob("#{folder_path}/*").length
  end

  def transform_polygon_to_params(folder_path, zip_file_path= @file, language = @language)
    check_file_size
    extractor = PolygonExtractor.new(folder_path, zip_file_path, language)
    description = extractor.extract_ploygon_problem
    description = filter_json_by_keys(description, poloygon_permit_key)

    @problem.name = description["name"]
    @problem.description = description["legend"]
    @problem.input = description["input"]
    @problem.output = description["output"]
    @problem.specjudge_type = "polygon"
    @problem.interlib_type = "none"
    @problem.sjcode = description["checker"]

    for i in description["examplein"].keys
      @problem.sample_testdata.build(
        input: description["examplein"][i],
        output: description["exampleout"][i],
      )
    end

    #binding.remote_pry
    description["testdata_pair"].each do |index, td_pair|
    infile_path,outfile_path = td_pair

      infile = File.open(infile_path, "r");
      outfile =  File.open(outfile_path, "r");

      @problem.testdata.build(
        test_input: infile,
        test_output: outfile,
        time_limit: description["timeLimit"]*1000,
        rss_limit: description,
        output_limit: description["maxOutputSize"]
      );
    end


    description["group"].each do |group, value|
      @problem.subtasks.build(
        td_list: value["problem index"].join(","),
        constraints: "",
        score: value["score"]
      );
    end

    return nil
  end

  private

  def set_base_problem
    @problem.name = ""
    @problem.tag_list = []
    @problem.solution_tag_list = []
    @problem.visible_state = "invisible"
    @problem.description = ""
    @problem.input =""
    @problem.output =""
    @problem.hint = ""
    @problem.source = ""
    @problem.discussion_visibility = "readonly"
    @problem.specjudge_type = "none"
    @problem.interlib_type = "none"
    @problem.num_stages = 1
    @problem.score_precision = 2
    @problem.specjudge_compiler_id = 1
    @problem.specjudge_compile_args = ""
    @problem.sjcode = ""
    @problem.judge_between_stages = 0
    @problem.default_scoring_args = ""
    @problem.interlib = ""
    @problem.interlib_impl = ""
    @problem.code_length_limit = 5000000
    @problem.ranklist_display_score = 0
    @problem.skip_group = 0
    @problem.strict_mode = 0
    @problem.verdict_ignore_td_list = ""
    @problem.summary_type = 0
  end

  def assert(condition, message)
    if not condition
      raise ArgumentError.new(message)
    end
  end

  def check_file_size
    assert(@file.size < FILE_LIMIT, "File size should not bigger that 5GiB")
  end

  def is_zip_file?(file)
    return file.content_type == "application/zip"
  end



  def filter_json_by_keys(json, keys)
    missing_keys = keys - json.keys
    filtered_json = json.select { |key, value| keys.include?(key) }

    if missing_keys.length > 0
      raise ArgumentError.new("Missing keys: #{missing_keys}")
    end

    JSON.parse(filtered_json.to_json)
  end


  #get the next 2^k > v
  def next_power_of_2(v)
    k = 1
    while k <= v
      k*=2
    end
    return k
  end


  def zjson_permit_key
    ["title","backgrounds","keywords","display","content","theinput","theoutput","hint","author","inserttime","updatetime","testinfiles","testoutfiles","scores","timelimits","memorylimit","sampleinput","sampleoutput", "judgemode", "specialjudge_code", "specialjudge_language"]
  end

  def poloygon_permit_key
    ["name","legend","input","output","examplein","exampleout","memoryLimit","timeLimit","testdata_pair","maxOutputSize", "group","checker"]
  end

end
