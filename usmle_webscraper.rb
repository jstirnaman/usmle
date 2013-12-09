require "rubygems"
require "open-uri"
require "nokogiri"
require "logger"
require "csv"

class Usmle

  def initialize(step)       
    @usmle_step = step    
  end  
  
  def usmle_step
    @usmle_step
  end
  
  def start_doc
    # Create a Nokogiri:HTML:Document
    # from our web page for parsing and searching.
    #start_page = "http://www.usmle.org/Examinations/step1/content/principles.html"
    start_doc = Nokogiri::HTML(open("http://www.usmle.org/Examinations/step1/content/principles.html"))
    STDERR.puts "Opened start page"
    STDERR.puts "Parsing errors: " + start_doc.errors.to_s
    @start_doc = start_doc
  end
  
  # 1. Match URLs within our document's navigation menu.
  # 2. Add them to an array.
  def get_links(pathpart)
    links = []
    start_doc.css('div#right a[@href]').each do |a|
      if (/^\/Examinations\/#{usmle_step}\/#{pathpart}\.html/) =~ a['href']
         #If the URL matches what we want, then URL-encode it and
         #push it to the end of an array.
        link = URI.escape("http://usmle.org"+a['href'])
        links.push(link)
      end
    end
    STDERR.puts "Matched #{links.count} links"
    return links
  end
  
  # Wrapper around get_links for matching intro page url
  def get_intro_links
    return get_links(usmle_step)
  end
  
  # Wrapper around get_links for matching description page url
  def get_description_links
    f = usmle_step + '(.*)_content'
    return get_links(f)
  end
  
  # Wrapper around get_links for matching content pages urls
  def get_content_links
    content_links = []
    content_links = get_links('.*content\/.*')
    return content_links
  end
  
  # Get web pages for each Step exam
  # Start by gathering the URLs from our pageurl's nav.
  # We could write these to a file or just hold them
  # in memory while we process the page content.
  # get_intro_links('step1')
  # get_description_links('step1')
  # get_content_links('step1')
  
  # Scrape the returned pages and format the stuff we want.
  
  # Some test URLs
  #intro_path = "http://www.usmle.org/Examinations/step1/step1.html"
  #content_desc_path = "http://www.usmle.org/Examinations/step1/step1_content.html"
  #content_path = "http://www.usmle.org/Examinations/step1/content/principles.html"
  
  def parse_intro_page
    get_intro_links.each do |l|
      begin
        doc = Nokogiri::HTML(open(l))
      rescue OpenURI::HTTPError, NameError => intro_http_error
       puts "HTTP Error:" + l.to_s
      end  
      intro = doc.css("h1")
      doc.css("div#left div#body p").each do |p|
         intro << p
      end
      return intro
    end  
  end
  
  def parse_desc_page
    @description = Nokogiri::XML::NodeSet.new(new_xml_doc)
    get_description_links.each do |l|
      begin
        doc = Nokogiri::HTML(open(l))
      rescue OpenURI::HTTPError, NameError => desc_http_error
       puts "HTTP Error:" + l.to_s    
      end        
      #Get div#left > div#body
      @description = @description | doc.css("div#left div#body p")      
    end
    return @description
  end
  
  def parse_content_page
    # Define an empty nodeset so we can append
    # nodesets from multiple pages.

    content_links = get_content_links
    #@content_pages = Nokogiri::XML::NodeSet.new(new_xml_doc)
    @content_pages = ''
    content_links.each do |l|
      STDERR.puts "Parsing #{l} \n Link #{content_links.index(l)} of #{content_links.count}"
      begin
        doc = Nokogiri::HTML(open(l))
      rescue OpenURI::HTTPError, NameError => content_http_error      
       puts "HTTP Error:" + l.to_s    
      end

      begin
       content_page = doc.css("div#left div#body").each do |node|
       end
      rescue Exception
        puts "Content parsing problem"
      end
      STDERR.puts "Finished parsing link"
      
      begin
        @content_pages = @content_pages + content_page
      rescue Exception
        puts "Exception: Merging content_page to @content_pages"
      end
    end
    return @content_pages
  end
  
  
   def parse_content_page_as_text
    content_links = get_content_links
    #@csv_arr = []
   @parsed = ''
   @doc = ''
    filename = "scraped/usmle#{usmle_step}.txt"
    STDERR.puts "Opening " + filename
        File.open(filename, "w") do |file|                 
      
    content_links.each do |l|
      STDERR.puts "Parsing #{l} \n Link #{content_links.index(l)} of #{content_links.count}"
        doc = Nokogiri::HTML(open(l))
        #@csv_string = ""

       doc_body = doc.css("div#left div#body")

       doc_body.children.each do |node|

       if node.element?
         case node.node_name
           when 'h1'        
             node = node.replace(node.inner_text.gsub(/(\r\n)*\t\s*/,''))
             file.puts node.to_s.strip
           when 'h2'
             node = node.replace(node.inner_text.gsub(/(\r\n)*\t\s*/,''))
             file.puts "\t"+node.to_s
           when 'p'
             node.children.each do |strong|
               if strong.node_name == 'strong'
                 strong = strong.replace(strong.inner_text.gsub(/(\r\n)*\t\s*/,''))
                 file.puts "\t\t"+strong.to_s
               end
             end
           when 'ul'
             node.children.each do |li|
               if li.node_name == 'li'
                 li.children.each do |lichild|
                   if lichild.text?
                     lichild = lichild.replace(lichild.inner_text.gsub(/(\r)*(\n)*(\t)*/,'').strip)
                     #Put any "including" statements into the ConceptSearch Clues for indexing.
                     #Make sure tabs are set correctly for number and sequence of columns you want.
                     lichild = lichild.to_s.gsub(/\(?\s*including(.*)\)?/){|s| "\t"+$1.strip}
                     file.puts "\t\t\t"+lichild.to_s
                   else
                   lichild.children.each do |liul|
                     liul.traverse do |lili|
                       if lili.node_name == 'li'
                         lili = lili.replace(lili.inner_text.gsub(/(\r)*(\n)*(\t)*/,'').strip)
                         lili = lili.to_s.gsub(/\(?\s*including(.*)\)?/){|s| "\t"+$1.strip}
                         file.puts "\t\t\t\t"+lili.to_s
                       end
                     end
                   end
                   end
                  end
               end
             end
         end
       end
     end
       @doc = @doc + doc_body.to_s
    end
       
       #@doc = doc.css("div#left div#body h2")
#          parsed = ''
#          parsed += node.css("h2").inner_text
#         parsed += node.css("p strong").each{|n| n.replace("\t\t"+node.css("p strong").inner_text+"\n")}
#         parsed += node.css("ul li").each{|n| n.replace("\t\t\t"+node.css("ul li").inner_text+"\n")}
#          @parsed = @parsed + parsed.to_s 
#     end
               
    end
return @doc
  end
  
  
  def new_xml_doc
    @xmldoc = Nokogiri::XML::Document.new
  end
  
  def save_xml 
        xmldoc = new_xml_doc       
         
      # Wrap our node set and write our XML document to a file
        filename = "scraped/usmle#{usmle_step}.xml"
        File.open(filename, "w") do |file|
          file.puts xmldoc
          file.puts '<div id="usmle_step">'
        end

        File.open(filename, "a") do |file|
          file.puts parse_intro_page
        end
        File.open(filename, "a") do |file|
          file.puts parse_desc_page 
        end
        File.open(filename, "a") do |file|
          file.puts parse_content_page
          #file.puts parse_content_page_as_text
          file.puts "</div>"          
      end 
  end
  
  def new_csv_doc

  end

#  def save_csv
#    filename = "usmle#{usmle_step}.txt"
#
#    STDERR.puts "Opening " + filename
#        File.open(filename, "w") do |file|        
#          file.puts parse_content_page_as_text
#      end
#  end
end

#ARGV.each do |usmle_step|
#  STDERR.puts "Starting #{usmle_step}"
#  usmle_doc = Usmle.new(usmle_step)
#  usmle_doc.save_xml
#end

ARGV.each do |usmle_step|
  STDERR.puts "Starting #{usmle_step}"
  usmle_doc = Usmle.new(usmle_step)
  usmle_doc.parse_content_page_as_text
end
