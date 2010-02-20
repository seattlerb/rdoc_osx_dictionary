#!/usr/bin/ruby -w

require 'fileutils'
require 'rdoc/ri/driver'

$q ||= false

# Forces /bin/tr to ignore badly formatted "unicode". (no clue where from)
ENV['LANG'] = ""
ENV['LC_ALL'] = "C"

class RDoc::OSXDictionary
  VERSION = '1.3.0'

  EXCLUDE = {
    "StringScanner#pre_match"  => true,
    "StringScanner#post_match" => true,
    "Gem::Package::TarInput"   => true,
    "IRB::OutputMethod"        => true,
  }

  NAME_MAP = {
    '!'   => 'bang',
    '%'   => 'percent',
    '&'   => 'and',
    '*'   => 'times',
    '**'  => 'times2',
    '+'   => 'plus',
    '-'   => 'minus',
    '/'   => 'div',
    '<'   => 'lt',
    '<='  => 'lte',
    '<=>' => 'spaceship',
    "<\<" => 'lt2',
    '=='  => 'equals2',
    '===' => 'equals3',
    '=~'  => 'equalstilde',
    '>'   => 'gt',
    '>='  => 'ge',
    '>>'  => 'gt2',
    '+@'  => 'unary_plus',
    '-@'  => 'unary_minus',
    '[]'  => 'idx',
    '[]=' => 'idx_equals',
    '^'   => 'carat',
    '|'   => 'or',
    '~'   => 'tilde',
    '='   => 'eq',
    '?'   => 'eh',
    '`'   => 'backtick',
    '::'  => '__',
  }

  NAME_MAP_RE = Regexp.new(NAME_MAP.keys.sort_by { |k| k.length }.map {|s|
                              Regexp.escape(s)
                            }.reverse.join("|"))


  def id *args
    args.map { |s| s.gsub(/:/, ',') }.join(",").gsub(/#{NAME_MAP_RE}/) { |x|
      ",#{NAME_MAP[x]}"
    }
  end

  def display_class_info definition
    name       = definition["name"]
    fullname   = definition["full_name"]
    supername  = definition["superclass"]
    type       = supername ? "class" : "module"
    title      = supername ? "class #{fullname} < #{supername}" : "module #{fullname}"
    comment    = Array(definition["comment"]).join("\n")

    definition["includes"].map!  { |c| c["name"] }
    definition["constants"].map! { |c| c["name"] }

    return if $q and fullname !~ /^(String|Array|Bignum)/

    comment = "Improperly formatted" if EXCLUDE[fullname]

    result = []

    shortname = "<d:index d:value=#{name.munge.inspect}/>" if name != fullname

    result << <<-"EOD".gsub(/^    /, '')
    <d:entry id="#{id type, fullname}" d:title="#{fullname}">
      <d:index d:value="#{fullname.munge}"/>
      #{shortname}
      <h1>#{title.munge}</h1>

      #{comment}
    EOD

    extensions = []

    definition["sources"].shift # remove first one as the original source
    definition["sources"].each do |path|
      next if path =~ /^.System/

      gemname   = File.basename(path.sub(%r(/ri/\w+/cdesc-\w+.yaml), ''))
      extension = YAML.load File.read(path).gsub(/- !.+/, '-')

      extension["includes"].map!  { |c| c["name"] }
      extension["constants"].map! { |c| c["name"] }

      detail = class_details(name, fullname, extension, 4)

      next if detail.empty?

      extensions << "<h3>#{gemname}:</h3>"
      extensions << detail
      %w(class_methods instance_methods includes constants).each do |k|
        definition[k] -= extension[k]
      end
    end

    result << class_details(name, fullname, definition)
    result << "<h2>Extensions:</h2>" unless extensions.empty?
    result << extensions

    result << <<-"EOD".gsub(/^    /, '')
    </d:entry>
    EOD
    result.join("\n")
  end

  def class_details name, fullname, definition, level = 2
    h = "h#{level}"
    result     = []
    includes   = definition["includes"]
    constants  = definition["constants"]

    classmeths = definition["class_methods"].map { |hash|
      name = hash["name"]
      "<a href=\"x-dictionary:r:#{id "defs", fullname, name}\">#{name}</a>"
    }

    instmeths  = definition["instance_methods"].map { |hash|
      name = hash["name"]
      "<a href=\"x-dictionary:r:#{id "def", fullname, name}\">#{name.munge}</a>"
    }

    [["Includes",         includes],
     ["Constants",        constants],
     ["Class Methods",    classmeths],
     ["Instance Methods", instmeths],
    ].each do |n, a|
      next if a.empty?

      result << "<#{h}>#{n}:</#{h}><p>#{a.join ", "}</p>"
    end

    result
  end

  def display_method_info definition
    fullname = definition["full_name"]
    klass = definition["class"]
    name = definition["name"]

    return if $q and klass !~ /^(String|Array|Bignum)/

    return if name =~ /_reduce_\d+/

    params = definition["params"]
    comment = Array(definition["comment"]).join("\n")
    comment = "undocumented" if comment.empty?

    comment = "Improperly formatted" if EXCLUDE[fullname]

    type = definition["is_singleton"] ? "defs" : "def"

    # TODO: aliases don't have recv
    # TODO: some regular methods don't have recv

    result = <<-"EOD".gsub(/^    /, '')
    <d:entry id="#{id type, klass, name}" d:title="#{fullname.munge}">
      <d:index d:value="#{fullname.munge}"/>
      <d:index d:value="#{name.munge}"/>
      <h1>#{fullname.munge}</h1>
      <pre class="signatures">
        #{d_signatures(name, params)}
      </pre>
      #{comment}
    </d:entry>
  EOD
  end

  def d_signatures name, params
    result = " "
    if params.strip =~ /^\(/
      result << "<b>#{name.munge}</b>"
    end
    result << "<b>#{params.munge.gsub(/\n/, "<br />")}</b>"
  end

  def d_header
    result = <<-"EOD"
<?xml version="1.0" encoding="UTF-8"?>
<!--
  This is a sample dictionary source file.
  It can be built using Dictionary Development Kit.
-->
<d:dictionary xmlns="http://www.w3.org/1999/xhtml" xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng">
  EOD
  end

  def d_entry fullname, definition, klass = false
    if klass then
      display_class_info definition
    else
      display_method_info definition
    end
  end

  def d_footer
    result = <<-"EOD"
<d:entry id="front_back_matter" d:title="Front/Back Matter">
  <h1><b>RubyGems Dictionary</b></h1>
  <h2>Front/Back Matter</h2>
  <div>
    Provides dictionary definitions for all known installed ruby gems.<br/><br/>
  </div>
  <div>
    <b>To see</b> this page,
    <ol>
      <li>Open "Go" menu.</li>
      <li>Choose "Front/Back Matter" menu item.
      If it has sub-menu items, choose one of them.</li>
    </ol>
  </div>
  <div>
    <b>To prepare</b> the menu item, do the followings.
    <ol>
      <li>Prepare this page source as an entry.</li>
      <li>Add "DCSDictionaryFrontMatterReferenceID" key and its value to the plist of the dictionary.
      The value should be the string of this page entry id. </li>
    </ol>
  </div>
  <br/>
</d:entry>
</d:dictionary>
  EOD
  end

  def make
    base  = File.expand_path "~/.ri/"

    FileUtils.rm_rf base if $d

    seen  = {}
    ri    = RDoc::RI::Driver.new
    dirty = false
    force = $f || false
    dict  = ri.class_cache

    dict.sort.each do |klass, definition|
      path = "#{base}/cache/#{klass}.xml"

      next if seen[klass.downcase]
      seen[klass.downcase] = true

      unless File.exist? path then
        warn "New entries for dictionary. Rebuilding dictionary." unless dirty
        dirty = true

        warn klass if $v

        File.open(path, "w") do |f|
          methods = ri.load_cache_for(klass)
          next if methods.nil? || methods.empty?
          result = []
          result << d_entry(klass, dict[klass], true)

          methods.each do |k,v|
            v["class"] = klass
            result << d_entry(k, v)
          end

          f.puts result.join("\n")
        end
      end
    end

    return unless dirty unless force

    dict_src_path = "#{base}/RubyGemsDictionary.xml"

    seen.clear

    File.open(dict_src_path, "w") do |xml|
      xml.puts d_header

      dict.sort.each do |klass, definition|
        next if seen[klass.downcase]
        seen[klass.downcase] = true

        path = "#{base}/cache/#{klass}.xml"
        body = File.read path rescue nil
        if body then
          xml.puts body
        else
          warn "Skipping: couldn't read: #{path}"
        end
      end

      xml.puts d_footer
    end

    dict_name = "RubyAndGems"
    data      = File.expand_path("#{__FILE__}/../../data")
    dict_path = File.expand_path "~/Library/Dictionaries"

    Dir.chdir base do
      run("/Developer/Extras/Dictionary Development Kit/bin/build_dict.sh",
          dict_name, dict_src_path,
          "#{data}/RubyGemsDictionary.css",
          "#{data}/RubyGemsInfo.plist")
    end

    warn "installing"

    FileUtils.mkdir_p dict_path

    run "rsync", "-r", "#{base}/objects/#{dict_name}.dictionary", dict_path

    FileUtils.touch dict_path

    warn "installed"
    warn "Run Dictionary.app to use the new dictionary. (activate in prefs!)"
  end

  def run(*cmd)
    warn "running: " + cmd.map { |s| s.inspect }.join(" ") if $v
    abort "command failed" unless system(*cmd)
  end

  @hooked = {}

  def self.install_gem_hooks
    return if @hooked[:hook]

    rdoc_osx_dictionary_path = File.expand_path File.join(__FILE__, "../../bin/rdoc_osx_dictionary")
    cmd = "#{Gem.ruby} #{rdoc_osx_dictionary_path}"

    # post_install isn't actually fully post-install... so I must
    # force via at_exit :(
    Gem.post_install do |i|
      at_exit do
        next if @hooked[:install]
        @hooked[:install] = true
        warn "updating OSX ruby + gem dictionary, if necessary"
        system cmd
      end
    end

    Gem.post_uninstall do |i|
      at_exit do
        next if @hooked[:uninstall]
        @hooked[:uninstall] = true
        require 'fileutils'
        warn "nuking old ri cache to force rebuild"
        FileUtils.rm_r File.expand_path("~/.ri")
        system cmd
      end
    end

    @hooked[:hook] = true
  end
end

class String
  def munge
    self.gsub(/&/, '&amp;').gsub(/>/, '&gt;').gsub(/</, '&lt;').gsub(/-/, '&#45;')
  end
end

class RDoc::Markup::Flow::LIST # ARG!
  def to_s
    pre, post = { :NUMBER => ['<ol>', '</ol>'] }[self.type] || ['<ul>', '</ul>']

    raise "no: #{self.type}" unless pre

    "#{pre}#{contents.join("\n")}#{post}"
  end
end

class Struct
  alias :old_to_s :to_s

  MARKUP = {
    "RULE" => [nil, nil],
    "H"    => ["<h2>", "</h2>"],
    "P"    => ["<p>", "</p>"],
    "VERB" => ["<pre>", "</pre>"],
    "LI"   => ['<li>', '</li>'],
  }

  def body
    self.text
  end

  def to_s
    name = self.class.name
    if name =~ /Flow/ then
      short = name.split(/::/).last
      raise short unless MARKUP.has_key? short
      pre, post = MARKUP[short]
      return "" unless pre
      "#{pre}#{self.body}#{post}"
    else
      old_to_s
    end
  end
end
