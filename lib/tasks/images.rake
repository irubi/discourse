task "images:compress" => :environment do
  io = ImageOptim.new
  images = Dir.glob("#{Rails.root}/app/**/*.png")
  image_sizes = Hash[*images.map{|i| [i,File.size(i)]}.to_a.flatten]
  io.optimize_images!(images) do |name, optimized|
    if optimized
      new_size = File.size(name)
      puts "#{name} => from: #{image_sizes[name.to_s]} to: #{new_size}"
    end
  end
end

desc "updates reverse index of image uploads"
task "images:reindex" => :environment do
	RailsMultisite::ConnectionManagement.each_connection do |db|
		puts "Reindexing #{db}"
    Post.select([:id, :cooked]).find_each do |p|
			doc = Nokogiri::HTML::fragment(p.cooked)
			doc.search("img").each do |img|
				src = img['src']
				if src.present? && Upload.has_been_uploaded?(src) && m = Upload.uploaded_regex.match(src)
          begin
            PostUpload.create({ post_id: p.id, upload_id: m[:upload_id] })
          rescue ActiveRecord::RecordNotUnique
          end
				end
			end
      putc "."
		end
  end
  puts "\ndone."
end

desc "clean orphan uploaded files"
task "images:clean_orphans" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Cleaning up #{db}"
    # ligthweight safety net to prevent users from wiping all their uploads out
    if PostUpload.count == 0 && Upload.count > 0
      puts "The reverse index is empty. Make sure you run the `images:reindex` task"
      next
    end
    Upload.joins("LEFT OUTER JOIN post_uploads ON uploads.id = post_uploads.upload_id")
          .where("post_uploads.upload_id IS NULL")
          .find_each do |u|
      u.destroy
      putc "."
    end
  end
  puts "\ndone."
end
