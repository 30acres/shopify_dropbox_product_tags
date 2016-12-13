require "dropbox_product_tags/version"

module DropboxProductTags
  require "dropbox_product_tags/product"
  require "dropbox_product_tags/product_tag_data"

  def self.update_all_products(path=nil, token=nil)
    payload = ''
    ImportProductTags.update_all_product_tags(path,token)
    payload = 'Successful Import (More info soon...)'
    payload
  end

end
