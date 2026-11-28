module HeroiconsHelper
  # The first `d` of a synced Heroicons file, which is what proves which drawing an icon came from.
  def path_of(variant, name)
    File.read(Rails.root.join("app/assets/svg/icons/heroicons/#{variant}/#{name}.svg"))[/ d="([^"]+)"/, 1]
  end
end
