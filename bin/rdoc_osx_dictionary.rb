#!/usr/bin/ruby -ws

$v ||= false

require 'pp'
require 'rubygems'
require 'rdoc/ri/driver'

base = File.expand_path("~/Work/p4/zss/src/newri/dev")
$:.unshift base
$:.unshift File.join(base, "lib")
load File.join(base, "bin/ri")

$, = ", "
$homepath.sub!(/rdoc/, 'ri') # HACK - RI::Paths.raw_path lies

exclude = ["ActiveRecord::ConnectionAdapters::Column::new",
           "IRB::OutputMethod#parse_printf_format",
           "IRB::SLex#postproc",
           "StringScanner#pre_match",
           "StringScanner#post_match",
           "Transaction::Simple",
          ]

$exclude = Hash[*exclude.map { |k| [k, true] }.flatten]

path = File.expand_path("~/.ri/cache/classes")
system "ri Array > /dev/null" unless File.exist? path
dict = Marshal.load File.read(path)

class String
  def munge
    self.gsub(/&/, '&amp;').gsub(/>/, '&gt;').gsub(/</, '&lt;')
  end
end

module SM
  remove_const :Flow
  Flow = RDoc::Markup::Flow
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

def display_class_info definition
  name       = definition["name"]
  fullname   = definition["full_name"]
  supername  = definition["superclass"]
  includes   = (definition["includes"]||[]).join(", ")
  classmeths = definition["class_methods"].map { |hash| hash["name"] }
  instmeths  = definition["instance_methods"].map { |hash| hash["name"] }
  type       = supername ? "class" : "module"
  title      = supername ? "class #{fullname} < #{supername}" : "module #{fullname}"
  comment    = Array(definition["comment"]).join("\n")
  constants  = Array(definition["constants"])
  sources    = definition["sources"].map { |path|
    next if path =~ /^.System/
    path.sub(%r%^.*?1\.[89]/doc/([^/]+).*%, '\1')
  }.compact

  comment = "Improperly formatted" if $exclude[fullname]

  id = "#{type}_#{fullname}".munge.gsub(/[\s:.#]/, '_')

  result = []

  result << <<-"EOD".gsub(/^    /, '')
    <d:entry id="#{id}" d:title="#{fullname}">
      <d:index d:value="#{fullname.munge}"/>
      <d:index d:value="#{name.munge}"/>
      <h1>#{title.munge}</h1>

      #{comment}
  EOD

  constants.map! { |c| c["name"] }

  ext, ext_type = sources.size == 1 ? ["From", :str] : ["Extensions", :list]

  [["Includes", includes.munge, :str],
   ["Constants", constants.join(", "), :str],
   ["Class Methods", classmeths.join(", ").munge, :str],
   ["Instance Methods", instmeths.join(", ").munge, :str],
   [ext, sources, ext_type]].each do |n, s, t|
    next if s.empty?
    case t
    when :str then
      result << "<h3>#{n}:</h3><p>#{s}</p>"
    when :list then
      items = s.map { |o| "<li>#{o}</li>" }.join("\n")
      result << "<h3>#{n}:</h3><ul>#{items}</ul>"
    else
      raise "unknown type #{t.inspect}"
    end
  end

  %w(name comment superclass includes constants class_methods
     instance_methods sources display_name full_name).each do |name|
    definition.delete name
  end

  result << <<-"EOD".gsub(/^    /, '')
    </d:entry>
  EOD
  result.join("\n")
end

$name_map = {
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
}

$name_map_re = Regexp.new($name_map.keys.sort_by { |k| k.length }.map {|s|
                            Regexp.escape(s)
                          }.reverse.join("|"))

def display_method_info definition
  fullname = definition["full_name"]
  name = definition["name"]
  id = fullname.gsub(/:|#/, '_').gsub(/#{$name_map_re}/) { |x| "_"+$name_map[x] }

  params = definition["params"]
  comment = Array(definition["comment"]).join("\n")
  comment = "undocumented" if comment.empty?

  comment = "Improperly formatted" if $exclude[fullname]

  result = <<-"EOD".gsub(/^    /, '')
    <d:entry id="def_#{id}" d:title="#{id}">
      <d:index d:value="#{fullname.munge}"/>
      <d:index d:value="#{name.munge}"/>
      <h1>#{fullname.munge}</h1>
      <p class="signatures">
        <b>#{name.munge}#{params.munge}</b>
      </p>
      #{comment}
    </d:entry>
  EOD
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

seen = {}

File.open("RubyGemsDictionary.xml", "w") do |xml|
  xml.puts d_header

  dict.sort.each do |klass, definition|
    # next unless klass =~ /^(IO|File)$/
    path = File.expand_path("~/.ri/cache/#{klass}.xml")

    next if seen[klass.downcase]
    seen[klass.downcase] = true

    unless File.exist? path then
      warn klass if $v

      File.open(path, "w") do |f|
        methods = load_cache_for(klass)
        next if methods.empty?
        result = []
        result << d_entry(klass, dict[klass], true)

        methods.each do |k,v|
          result << d_entry(k, v)
        end
        result = result.join("\n")
        f.puts result
        xml.puts result
      end
    else
      xml.puts File.read(path)
    end
  end

  xml.puts d_footer
end
