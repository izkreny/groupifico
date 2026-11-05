require "rails_helper"

RSpec.describe "Active Storage's own routes", type: :request do
  it "stores no direct upload" do
    post "/rails/active_storage/direct_uploads", params: { blob: { filename: "a.png", byte_size: 4, checksum: "AAAAAAAAAAAAAAAAAAAAAA==", content_type: "image/png" } }

    expect(response).to have_http_status :not_found
    expect(ActiveStorage::Blob.count).to eq 0
  end

  it "accepts no upload to the disk service, even at a signed upload URL" do
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "a.png", byte_size: 4, checksum: Digest::MD5.base64digest("PNG!"), content_type: "image/png")
    token = ActiveStorage.verifier.generate({ key: blob.key, content_type: "image/png", content_length: 4, checksum: blob.checksum, service_name: blob.service_name }, expires_in: 5.minutes, purpose: :blob_token)

    put "/rails/active_storage/disk/#{token}", params: "PNG!", headers: { "Content-Type" => "image/png" }

    expect(response).to have_http_status :not_found
    expect(blob.service.exist?(blob.key)).to be false
  end
end
