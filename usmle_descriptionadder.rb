require "rubygems"
require "open-uri"
require "nokogiri"
require "logger"
require "csv"

# Since the ConceptSearch CSV importer doesn't accept descriptions
# this class takes the XML file from ConceptSearch Taxonomy Converter
# and inserts description elements from a second text file containing
# one description per line. We're assuming that class IDs in the 
# taxonomy XML file match the line number in the descriptions file.

class UsmleTermDescriptions
  def initialize
    @description_file = read_description_file
    @taxml = create_taxml
  end
  
  # Load the taxonomy xml into a Nokogiri XML doc.
  def create_taxml
    Nokogiri::XML(open('./CS_terms_usmle.xml'))  
  end
  
  def insert_descriptions
       @taxml.xpath('//class').each do |c|
        # Get the classid node value for each class node
        cid = c.at_xpath('classid').content.to_i
        desc_file = IO.readlines(@description_file)
        desc_str = desc_file[cid-1]
        c.add_child('<description>'+desc_str+'</description')
        
        #c.child('description').content = @description_file.readlines[cid]
      end
     taxml = @taxml
    File.open('export/CS_terms_usmle_descript.xml', "w") do |file|
      file.puts taxml.to_xml
    end
  end
 
  def read_description_file
    File.open('scraped/usmle_descriptions.txt', 'r')   
  end
  
  def find_descriptions
    # Open our descriptions file for reading.
        @description_file.each do |line|
          puts @description_file.lineno
          puts line.to_s
        end
    # Write each line of the descriptions file into
    # a description element of the matching class.
    
    # Write to a new file. Done.
  end
  
end

usmle_doc = UsmleTermDescriptions.new
usmle_doc.insert_descriptions
