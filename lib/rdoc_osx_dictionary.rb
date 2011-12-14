#!/usr/bin/ruby -w

require 'fileutils'
require 'rdoc/ri/driver'

$q ||= false

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

  def display_class_info definition, source
    fullname  = definition.full_name

    name      = definition.name
    is_class  = ! definition.module?
    supername = definition.superclass if is_class
    comment   = to_html.convert definition.comment

    type       = is_class ? "class" : "module"
    title      = is_class ? "class #{fullname} < #{supername}" : "module #{fullname}"

    comment = "Improperly formatted" if EXCLUDE[fullname]

    result = []

    shortname = "<d:index d:value=#{name.munge.inspect}/>" if name != fullname

    result << <<-"EOD".gsub(/^ {6}/, '')
      <d:entry id="#{id type, fullname}" d:title="#{fullname}">
        <d:index d:value="#{fullname.munge}"/>
        #{shortname}
        <h1>#{title.munge}</h1>

        #{comment}
    EOD

    result << class_details(name, fullname, definition)

    # TODO: proper extension support
    # detail = class_details(name, fullname, extension, 4)

      #  result << "<h2>Extensions:</h2>" unless extensions.empty? # FIX

      # extensions << "<h3>#{gemname}:</h3>"
      # extensions << detail
      # %w(class_methods instance_methods includes constants).each do |k|
      #   definition[k] -= extension[k]
      # end
    # end

    result << <<-"EOD".gsub(/^    /, '')
    </d:entry>
    EOD
    result.join("\n")
  end

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

  def display_method_info definition
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

    # HACK to deal with the Dictionary compiler fucking with me.
    comment = comment.gsub(/<span[^>]+>/, '').gsub(/<\/span>/, '')
    comment = comment.gsub(/(<pre[^>]*>)\s*\n/, '\1')

    result = <<-"EOD".gsub(/^ {6}/, '')
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
    params ||= ""
    if params.strip =~ /^\(/
      result << "<b>#{name.munge}</b>"
    end
    result << "<b>#{params.munge.gsub(/\n+/, "\n")}</b>"
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

    dir = File.join base, "dict"
    FileUtils.mkdir_p dir unless File.directory? dir

    dirty = false
    force = $f || false
    ri    = RDoc::RI::Driver.new
    dict  = ri.classes

    c_seen = {}
    m_seen = {} # HACK: known issue: on a case insensitive FS we're losing files
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

        File.open(path, "w") do |f|
          c_result, m_result = [], []

          extension = false
          m_seen.clear
          stores.each do |store|
            cdesc = store.load_class klass
            type  = store.type

            next if c_seen[[klass, type]]

            # HACK: fix me after store inversion dealt with
            next unless type == :system

            c_result << display_class_info(cdesc, store.friendly_path)

            cdesc.method_list.each do |method|
              next if m_seen[method.full_name.downcase]
              method = store.load_method klass, method.full_name
              m_result << display_method_info(method)
              m_seen[method.full_name.downcase] = true
            end

            extension = true
            c_seen[[klass, type]] = true
          end

          f.puts c_result.join("\n")
          f.puts m_result.join("\n")
        end
      end
    end

    warn "! YAY!! All done!!!" if dirty

    return unless dirty unless force

    dict_src_path = "#{base}/RubyGemsDictionary.xml"

    seen = {}

    File.open(dict_src_path, "w") do |xml|
      xml.puts d_header

      dict.sort.each do |klass, definition|
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

      xml.puts d_footer
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
