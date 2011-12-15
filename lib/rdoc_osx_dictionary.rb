#!/usr/bin/ruby -w

gem 'rdoc'
require 'fileutils'
require 'rdoc/ri/driver'

$d ||= false
$f ||= false
$q ||= false
$v ||= false

# Forces /bin/tr to ignore badly formatted "unicode". (no clue where from)
ENV['LANG'] = ""
ENV['LC_ALL'] = "C"

class RDoc::OSXDictionary
  VERSION = '1.3.1'

  EXCLUDE = {
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

  attr_reader :to_html

  def initialize
    @to_html = RDoc::Markup::ToHtml.new
  end

  def id *args
    args.map { |s| s.gsub(/:/, ',') }.join(",").gsub(/#{NAME_MAP_RE}/) { |x|
      ",#{NAME_MAP[x]}"
    }
  end

  def write_class_info klass, stores, path
    m_seen = {} # HACK: known issue: on a case insensitive FS we're losing files

    File.open(path, "w") do |f|
      c_result, m_result = [], []

      m_seen.clear
      seen_system = false

      fullname  = klass

      f.puts <<-"EOD".gsub(/^ {6}/, '')
        <d:entry id="#{id fullname}" d:title="#{fullname}">
          <d:index d:value="#{fullname.munge}"/>
      EOD

      first = true

      stores.each do |store|
        cdesc     = store.load_class klass
        type      = store.type
        from      = store.friendly_path
        name      = cdesc.name
        is_class  = ! cdesc.module?
        supername = cdesc.superclass if is_class
        comment   = to_html.convert cdesc.comment
        type      = is_class ? "class" : "module"
        title     = is_class ? "class #{fullname}" : "module #{fullname}"

        title += " < #{supername}" if is_class and supername != "Object"

        comment = "Improperly formatted" if EXCLUDE[fullname]

        shortname = "<d:index d:value=#{name.munge.inspect}/>" if name != fullname

        f.puts <<-"EOD".gsub(/^ {8}/, '')
            #{shortname}
            <h1>#{title.munge}</h1>
            <h3>From: #{from}</h3>

            #{comment}
        EOD

        level = first ? 2 : 4
        first = false

        f.puts class_details(name, fullname, cdesc, level)

        cdesc.method_list.each do |method|
          next if m_seen[method.full_name.downcase]
          method = store.load_method klass, method.full_name
          m_result << display_method_info(method, from)
          m_seen[method.full_name.downcase] = true
        end
      end # stores.each

      f.puts <<-"EOD".gsub(/^ {6}/, '')
        </d:entry>

      EOD

      f.puts m_result.join("\n\n")
    end
  end

  # REFACTOR: fold this back in
  def class_details name, fullname, definition, level = 2
    h         = "h#{level}"
    result    = []
    includes  = definition.includes.map { |c| c.name }
    constants = definition.constants.map { |c| c.name }

    classmeths = definition.singleton_methods.map { |cm|
      name = cm.name
      "<a href=\"x-dictionary:r:#{id "defs", fullname, name}\">#{name}</a>"
    }

    instmeths = definition.instance_method_list.map { |im|
      name = im.name
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

  def display_method_info definition, from
    klass     = definition.parent_name

    fullname  = definition.full_name
    name      = definition.name
    singleton = definition.singleton
    params    = definition.arglists
    comment   = to_html.convert definition.comment
    type      = singleton ? "defs" : "def"

    return if name =~ /_reduce_\d+/

    comment = "undocumented" if comment.empty?
    comment = "Improperly formatted" if EXCLUDE[fullname]

    # HACK to deal with the Dictionary compiler fucking with my whitespace.
    comment = comment.gsub(/<span[^>]+>/, '').gsub(/<\/span>/, '')
    comment = comment.gsub(/(<pre[^>]*>)\s*\n/, '\1')

    result = <<-"EOD".gsub(/^ {6}/, '')
      <d:entry id="#{id type, klass, name}" d:title="#{fullname.munge}">
        <d:index d:value="#{fullname.munge}"/>
        <d:index d:value="#{name.munge}"/>
        <h1>#{fullname.munge}</h1>
        <h3>From: #{from}</h3>
        <pre class="signatures">
          #{d_signatures(name, params)}
        </pre>
      #{comment}
      </d:entry>
    EOD
  end

  def d_signatures name, params
    result = " "
    params ||= ""
    if params.strip =~ /^\(/
      result << "<b>#{name.munge}</b>"
    end
    result << "<b>#{params.munge.gsub(/\n+/, "\n")}</b>"
  end

  def d_header
    result = <<-"EOD".gsub(/^ {6}/, '')
      <?xml version="1.0" encoding="UTF-8"?>
      <d:dictionary xmlns="http://www.w3.org/1999/xhtml" xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng">
    EOD
  end

  def d_footer classes, sources
    result = <<-"EOD".gsub(/^ {6}/, '')
      <d:entry id="front_back_matter" d:title="Front/Back Matter">
        <h1><b>RubyGems Dictionary</b></h1>

        <div>
          Provides dictionary definitions for ruby core, stdlib, and
          all known installed ruby gems.
        </div>

        <h3>Sources:</h3>
        <div>#{sources.keys.sort.join ", "}</div>

        <h3>Classes:</h3>
        <div>#{classes.keys.sort.join ", "}</div>
      </d:entry>
      </d:dictionary>
    EOD
  end

  def make
    base  = File.expand_path "~/.ri/"

    FileUtils.rm_rf base if $d

    dir = File.join base, "dict"
    FileUtils.mkdir_p dir unless File.directory? dir

    dirty = false
    force = $f || false
    ri    = RDoc::RI::Driver.new
    dict  = ri.classes

    l_seen = {}

    dict.sort.each do |klass, stores|
      path = "#{base}/dict/#{klass}.xml"

      next if $q and klass !~ /^(String|Array|Bignum)/

      unless File.exist? path then
        unless dirty then
          warn "New entries for dictionary. Rebuilding dictionary."
          warn "Sing along, kids!"
        end
        dirty = true
        warn klass if $v

        $stderr.print klass[0,1] unless l_seen[klass[0,1]]
        l_seen[klass[0,1]] = true

        write_class_info klass, stores, path
      end
    end

    warn "! YAY!! All done!!!" if dirty

    return unless dirty unless force

    dict_src_path = "#{base}/RubyGemsDictionary.xml"

    seen = {}

    classes = {}
    sources = {}
    ri.classes.sort.each do |klass, stores|
      classes[klass] = true

      stores.each do |store|
        sources[store.friendly_path] = true
      end
    end

    File.open(dict_src_path, "w") do |xml|
      xml.puts d_header

      dict.sort.each do |klass, stores|
        next if $q and klass !~ /^(String|Array|Bignum)/

        next if seen[klass]
        seen[klass] = true

        path = "#{base}/dict/#{klass}.xml"
        body = File.read path rescue nil
        if body then
          xml.puts body
        else
          warn "Skipping: couldn't read: #{path}"
        end
      end

      xml.puts d_footer(classes, sources)
    end

    dict_name = "RubyAndGems"
    data      = File.expand_path("#{__FILE__}/../../data")
    dict_path = File.expand_path "~/Library/Dictionaries"

    Dir.chdir base do
      run("/Developer/Extras/Dictionary Development Kit/bin/build_dict.sh",
          "-c=0",
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
    return unless File.exist? File.expand_path("~/.ri/autorun")

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
        FileUtils.rm_r File.expand_path("~/.ri/dict")
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
