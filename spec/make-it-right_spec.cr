require "./spec_helper"

TEST_FILE = File.read "spec/picture.jpg"

describe MakeItRight do
  it "Read and Write EXIF data from JIF files" do
    # Check various known thing about the picture

    tiff = MakeItRight.from_jif IO::Memory.new TEST_FILE
    tiff.should be_truthy

    tiff.try do |tiff|
      tiff.orientation.should eq MakeItRight::Orientation::TOP_LEFT

      tiff.next.should be_truthy
      tiff.next.try do |thumb|
        thumb.payload.should be_truthy
        thumb.payload.try do |payload|
          payload.size.should eq 1378
        end
      end

      tiff.gps.should be_truthy
      tiff.resolution_unit.should be_truthy
      tiff.resolution_unit.try(&.inch?).should be_true

      tiff.exif.should be_truthy
      tiff.exif.try do |exif|
        exif.exif_image_width.should eq 100
        exif.exif_image_height.should eq 68
        exif.interoperability.should be_truthy
      end

      # Do various changes

      tiff.orientation = MakeItRight::Orientation::BOTTOM_RIGHT
      tiff.gps = nil
      tiff.exif.try do |exif|
        exif.interoperability = tiff.new_subifd MakeItRight::Interoperability
        exif.next = tiff.new_subifd.tap do |a_completely_out_of_spec_ifd|
          a_completely_out_of_spec_ifd.orientation = MakeItRight::Orientation::BOTTOM_LEFT
        end
      end

      tiff.next.try do |thumb|
        thumb.payload = Bytes.new size: 4
      end

      # Write and Read again

      patched_io = IO::Memory.new
      MakeItRight.patch_jif tiff, IO::Memory.new(TEST_FILE), patched_io
      patched_io.rewind
      patched = MakeItRight.from_jif patched_io

      # Check change have been applied
      patched.should be_truthy
      patched.try do |patched|
        patched.orientation.should eq MakeItRight::Orientation::BOTTOM_RIGHT
        patched.gps.should be_nil
        patched.exif.should be_truthy
        patched.exif.try do |exif|
          exif.interoperability.should be_truthy
          exif.next.should be_truthy
          exif.next.try do |oos|
            oos.orientation.should eq MakeItRight::Orientation::BOTTOM_LEFT
          end
        end

        patched.next.should be_truthy
        patched.next.try do |thumb|
          thumb.payload.should be_truthy
          thumb.payload.try do |payload|
            payload.size.should eq 4
          end
        end
      end
    end
  end
end
