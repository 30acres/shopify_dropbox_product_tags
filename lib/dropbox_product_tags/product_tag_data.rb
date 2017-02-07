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
      # binding.pry
      ProductTagData.new(path).get_csv
      ProductTagData.process_products 
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
    already_imported = false
    puts "===== H E R E ====="
    if !already_imported
      @notifier.ping "[Product Data] Files Changed"
      CSV.parse(file, headers: true, :header_converters => :symbol) do |row|
        # encoded = CSV.parse(product).to_hash.to_json
        encoded = row.to_hash.inject({}) { |h, (k, v)| h[k] = v.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').valid_encoding? ? v.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') : '' ; h }
        # encoded_more = encoded.to_json
        if !row[:sku].blank?
          d = RawDatum.where(sku: row[:sku],client_id: 0, status: 10).first_or_create
          d.data = encoded
          d.save!
        end

      end
      Import.new(path: path).save!
    else
      @notifier.ping "[Product Data] No Changes"
    end
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
    puts "PUT PRODUCT PROCESS"
    @notifier = Slack::Notifier.new ENV['SLACK_CMW_WEBHOOK'], channel: '#cmw_data', username: 'Data Notifier', icon_url: 'https://cdn.shopify.com/s/files/1/1290/9713/t/4/assets/favicon.png?3454692878987139175'
    @notifier.ping "Processing...."
    shopify_variants = []
    [1,2,3,4,5,6].each do |page|
       shopify_variants << ShopifyAPI::Variant.find(:all, params: { limit: 250, fields: 'sku, product_id', page: page } )
    end
    shopify_variants = shopify_variants.flatten
    # binding.pry

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

    if variant.nil?
      puts 'NO MATCH'
    else
      puts 'MATCH FOUND'
      product = ShopifyAPI::Product.find(variant.product_id)
      oldtags = product.tags
    end
    metafields = Array.new([
      'product_awards',
      'product_ratings'
    ])

    ordered_tags = Array.new([
      'hot_price',
      'aks_choice',
      'reduced_to_clear',
      'last-stocks',
      'country',
      'estate',
      # 'product_awards',
      # 'product_ratings',
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

    v.product_id = product.id
    begin
    product.save!
    rescue
      binding.pry
    end

    metafields.each do |tag|
      if !(match.data[tag].nil? or (match.data[tag].to_s.downcase == 'n/a') or (match.data[tag].blank?))
        meta = ShopifyAPI::Metafield.new(namespace: 'product_details', key: tag, value: match.data[tag]., value_type: 'string', owner_resource: 'product', owner_id: @product.id)
        meta.save!
        puts '====================================='
        puts '=== M E T A  S A V E D ============================='
        puts '====================================='
      end
    end
    puts '====================================='
    puts '=== V A R I A N T S A V E D ============================='
    puts '====================================='

  end
end
