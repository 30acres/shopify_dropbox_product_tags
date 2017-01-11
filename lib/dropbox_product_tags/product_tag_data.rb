require 'net/http'
require 'dropbox_sdk'
require "product/product"
require 'csv'
require 'slack-notifier'

module ImportProductTags

  def self.update_all_products(path='https://s3.amazonaws.com/mydonedone.com/donedone_issuetracking_11034/ce292cb3-f1e4-43d2-ae4b-480b6da79b9b_/catalog_product_20161212_035806.csv')
      @notifier = Slack::Notifier.new ENV['SLACK_CMW_WEBHOOK'], channel: '#cmw_data',
        username: 'Data Notifier', icon: 'https://cdn.shopify.com/s/files/1/1290/9713/t/4/assets/favicon.png?3454692878987139175'
      @notifier.ping "[Product Data] Started Import"

    if path
      ## Clear the Decks
      ProductTagData.delete_datum

      ## get the csv
      # binding.pry
      puts 'Get Files'
      puts path
      ProductTagData.new(path).get_csv

      ## parse the rows
      ## update the descriptions
      puts 'Tag Data'
      ProductTagData.process_products
      puts 'End Process'

      ## Clear the decks again
      ProductTagData.delete_datum

      @notifier.ping "[Product Data] Finished Import"

    end

  end
end

class ProductTagData
  def initialize(path)
    @path = path
    @notifier = Slack::Notifier.new ENV['SLACK_CMW_WEBHOOK'], channel: '#cmw_data', username: 'Import Notifier', icon: 'https://cdn.shopify.com/s/files/1/1290/9713/t/4/assets/favicon.png?3454692878987139175'
  end

   def get_csv

    puts "===== H E R E ====="
    already_imported = Import.where(path: path).any?
    puts "===== H E R E ====="
    # unless already_imported
      @notifier.ping "[Product Data] Files Changed"
      FCSV.parse(file, headers: true, :header_converters => :symbol) do |row|
        puts file
        puts file.class
        puts row
        # encoded = CSV.parse(product).to_hash.to_json
        encoded = row.to_hash.inject({}) { |h, (k, v)| h[k] = v.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').valid_encoding? ? v.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') : '' ; h }
        encoded_more = encoded.to_json
        puts encoded_more
        RawDatum.create(data: encoded_more, client_id: 0, status: 10)

      end
      Import.new(path: path).save!
    # else
      # @notifier.ping "[Product Data] No Changes"
    # end
  end

  def self.delete_datum
    ## so cheap and dirty
    RawDatum.unscoped.where(status: 10).destroy_all
  end

  def path
    'https://s3.amazonaws.com/mydonedone.com/donedone_issuetracking_11034/ce292cb3-f1e4-43d2-ae4b-480b6da79b9b_/catalog_product_20161212_035806.csv'
  end

  def file
    open(path).read()
  end


  def self.process_products
    @notifier = Slack::Notifier.new ENV['SLACK_CMW_WEBHOOK'], channel: '#cmw_data', username: 'Data Notifier', icon_url: 'https://cdn.shopify.com/s/files/1/1290/9713/t/4/assets/favicon.png?3454692878987139175'
  
    shopify_variants = []
    [1,2,3,4,5,6].each do |page|
      # binding.pry
      ShopifyAPI::Variant.find(:all, params: { limit: 250, fields: 'sku, product_id', page: page } ).each do |sv|
        shopify_variants << sv
      end

    end
    shopify_variants = shopify_variants.flatten

    RawDatum.unscoped.where(status: 10).each do |data|
      # binding.pry
      code = data.data["sku"]
      puts code
      if shopify_variants.any? and !code.blank?
        matches = shopify_variants.select { |sv| sv.sku == code }
        # binding.pry
        if matches.any?
          # binding.pry
          v = matches.first
          ProductTagData.update_product_tags(v, data)
        else
          puts 'OI - NO MATCH FOUND'
          puts code 
          puts '======'
          sleep(10)
          # v = nil
          # ProductTagData.update_product_descriptions(v, data)
        end
      else
        # v = nil
        # ProductTagData.update_product_descriptions(v, data)
      end
    end

  end

  def self.update_product_tags(variant, match)
    puts '==== C R E D I T ===='
    puts ShopifyAPI.credit_used
    if ShopifyAPI.credit_used >= 38
      puts 'Chilling out...too much credit used!'
      sleep(20)
    end
    puts '---=============-----'
    sleep(1)
    oldtags = ''
    # clean_designers = [['Cline','Céline'],['lvaro','Álvaro'],['Vanessa Bruno (ath)','Vanessa Bruno (athé)'],['Marsll','Marsèll'],['Hrve Lger','Hérve Léger'],['Alaa','Alaïa']]


    if variant.nil?
      puts 'NO MATCH'
      # product = ShopifyAPI::Product.new
      # binding.pry
    else
      puts 'MATCH FOUND'
      product = ShopifyAPI::Product.find(variant.product_id)
      oldtags = product.tags
      # binding.pry
    end
    # designer = match.data["Designer"].strip

    # clean_designers.each do |cd|
    #   if designer.downcase == cd[0].downcase
    #     designer = cd[1]
    #   end
    # end

    # product.title = match.data["Product Title"].gsub('  ',' ')
    # clean_designers.each do |cd|
    #   product.title = product.title.gsub(cd[0],cd[1])
    # end

    # desc = match.data["Description"]
    # product.body_html = desc
    # product.product_type = match.data['Category']

    # product.vendor = designer

    # product.metafields_global_title_tag = product.title
    # product.metafields_global_description_tag = desc

    ordered_tags = Array.new([
'hot_price',
'aks_choice',
'reduced_to_clear',
'last-stocks',
'country',
'estate',
'product_awards',
'product_ratings',
'rating_cellarmaster',
'region',
'vintage',
'estate',
'awards_decanter_bronze',
'awards_decanter_gold',
'awards_decanter_silver',
'awards_international_bronze',
'awards_international_gold',
'awards_international_silver',
'awards_winespirits_bronze',
'awards_winespirits_gold',
'awards_winespirits_silver',
'rating_cellarmaster',
'rating_decantar',
'rating_enthusiast',
'rating_halliday',
'rating_oliver',
'rating_parker',
'rating_spectator',
'rating_suckling',
'rating_wro',
'backstock_preorders'
])
puts 'Got here'
  #
    tagz = []
    ordered_tags.each do |tag|
      if !(match.data[tag].nil? or (match.data[tag].to_s.downcase == 'n/a') or (match.data[tag].blank?))
        tagz << "#{tag.underscore.humanize.titleize}: #{match.data[tag].gsub('  ',' ').gsub(',','')}".strip
      end
    end
    product.tags = tagz.join(',')


    puts "#{product.title} :: UPDATED!!!"
    # if match.data["Publish on Website"] == 'Yes'
    #  if !product.id or (product.id and product.published_at.nil?)
    #     product.published_at = DateTime.now - 10.hours
    #   end
    # else
    #   product.published_at = nil
    # end
    puts product.inspect

    puts '====================================='
    puts '====================================='
    puts product
    puts '=== P R O D U C T S A V E D ==========================='

    # binding.pry
    if product.id
      v = product.variants.first
    else
      # v = ShopifyAPI::Variant.new
    end

    # ['Australian Size','Colour','Material'].each_with_index do |opt,index|
    #   # binding.pry
    #     if index == 0
    #       d = match.data[opt].to_s.strip
    #       v.option1 = d.blank? ? 'n/a' : d
    #     end
    #     if index == 1
    #       d = match.data[opt].to_s.strip
    #       v.option2 = d.blank? ? 'n/a' : d
    #     end
    #     if index == 2
    #       d = match.data[opt].to_s.strip
    #       v.option3 = d.blank? ? 'n/a' : d
    #     end
    # end

    # compare_at_price = Float(match.data["Price (before Sale)"].to_s.gsub('$','')) rescue false ? match.data["Price (before Sale)"] : nil

    v.product_id = product.id
    # v.price = match.data["Price"].gsub('$','').gsub(',','').to_s.strip.to_f
    # v.sku = match.data["*ItemCode"]
    # v.grams = match.data["Weight (grams)"].to_i
    # v.compare_at_price = compare_at_price

    # v.inventory_quantity = match.data["NumStockAvailable"]
    # v.old_inventory_quantity = match.data["NumStockAvailable"]
    # v.requires_shipping = true
    # v.barcode = nil
    # v.taxable = true
    # v.position = 1
    # v.inventory_policy = 'deny'
    # v.fulfillment_service = "manual"
    # v.inventory_management = "shopify"
    # # weight: match.data["Weight (grams)"].to_i/100,
    # v.weight_unit = "g"
    # puts v.inspect
    # # binding.pry
    # product.variants = [v]
    # binding.pry
    product.save!
    # v.save!
    puts '====================================='

    # if variant.nil?
    #   updates << "Product Data: New Product: #{product.title}"
    # else
    #   updates << "Product Data: Updated Product #{product.title}"
    # end

    puts '=== V A R I A N T S A V E D ============================='
    puts '====================================='

  end
end
