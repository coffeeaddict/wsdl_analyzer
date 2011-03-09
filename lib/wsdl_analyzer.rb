require 'nokogiri'

class WsdlAnalyzer
  attr_reader :doc

  def initialize file_name
    file = File.open(file_name)

    @doc = Nokogiri::XML file
    @doc.remove_namespaces!
  end

  def get_operations
    operations = []
    doc.xpath('/definitions/portType/operation').each do |op|
      operations<< [ op['name'], {
        :documentation => op.xpath('documentation').text,
        :input         => strip_ns(op.xpath('input').first['message']),
        :output        => strip_ns(op.xpath('output').first['message'])
      } ]
    end

    operations
  end

  def get_operation name
    operation = {}
    op = doc.xpath("/definitions/portType/operation[@name='#{name}']").first
    input  = strip_ns(op.xpath('input').first['message'])
    output = strip_ns(op.xpath('output').first['message'])

    fault = begin
      strip_ns(op.xpath('fault').first['message'])
    rescue
      nil
    end

    operation = {
      :documentation => op.xpath('documentation').text,
      :input         => get_message(input),
      :output        => get_message(output),
      :fault         => fault ? get_message(fault) : fault
    }
  end

  def get_message name, depth=0
    msg = []

    doc.xpath("/definitions/message[@name='#{name}']/part").each do |part|
      name = part['name']
      type = part['type']

      if type =~ /:/ and type !~ /xsd?:/
        type = strip_ns type
        name = "#{name}:#{type}"

        type = get_complex_type(type)
      else
        type = strip_ns type
      end

      msg << { name => type }
    end

    msg
  end

  def get_complex_type name, depth=0
    if depth == 20
      return "<strong>RECURSION 2 DEEP</strong>"
    end

    res = {}

    candidates  = doc.xpath(
      "/definitions/types/schema/element[@name='#{name}']/complexType/*"
    )
    candidates += doc.xpath(
      "/definitions/types/schema/complexType[@name='#{name}']/*"
    )

    candidates.each do |node|
      if node.name =~ /(all|sequence)/
        # a struct
        node.xpath(".//element").each do |element|
          type = (element['type'] || element['element'])
          name = element['name']

          if type =~ /:/ and type !~ /xsd?:/
            type = strip_ns(type)
            name = "#{name}:#{type}"

            res[name] = get_complex_type(type, depth + 1)

          else
            res[name] = strip_ns(type)

          end
        end

      elsif node.name =~ /complexContent/
        # an array
        res = []
        node.xpath('.//attribute').each do |attribute|
          type = attribute['arrayType'].gsub('[]', '')

          if type !~ /xsd?:/
            type = strip_ns(type)
            res << { type => get_complex_type(type, depth + 1) }

          else
            res << strip_ns(type)
          end
        end

      end
    end

    res
  end

  def strip_ns text
    text.gsub /^[^:]+:/, ''
  rescue
    ""
  end
end
