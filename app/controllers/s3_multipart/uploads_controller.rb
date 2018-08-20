module S3Multipart
  class UploadsController < ApplicationController

    def create
      begin
        upload = Upload.create(upload_params, session)
        upload.execute_callback(:begin, session)
        response = upload.to_json
      rescue FileTypeError, FileSizeError => e
        response = {error: e.message}
      rescue => e
        logger.error "EXC: #{e.message}"
        response = { error: t("s3_multipart.errors.create") }
      ensure
        render :json => response
      end
    end

    def update
      return complete_upload if upload_params[:parts]
      return sign_batch if upload_params[:content_lengths]
      return sign_part if upload_params[:content_length]
    end

    private

      def sign_batch
        begin
          response = Upload.sign_batch(upload_params)
        rescue => e
          logger.error "EXC: #{e.message}"
          response = {error: t("s3_multipart.errors.update")}
        ensure
          render :json => response
        end
      end

      def sign_part
        begin
          response = Upload.sign_part(upload_params)
        rescue => e
          logger.error "EXC: #{e.message}"
          response = {error: t("s3_multipart.errors.update")}
        ensure
          render :json => response
        end
      end

      def complete_upload
        begin
          response = Upload.complete(upload_params)
          upload = Upload.find_by_upload_id(upload_params[:upload_id])
          upload.update_attributes(location: response[:location])
          complete_response = upload.execute_callback(:complete, session)
          response[:extra_data] = complete_response if complete_response.is_a?(Hash)
        rescue => e
          logger.error "EXC: #{e.message}"
          response = {error: t("s3_multipart.errors.complete")}
        ensure
          render :json => response
        end
      end

      def upload_params
        params.permit(
          :id, :content_lengths, :content_length, :upload_id,
          :uploader, :content_size, :context,
          :content_type, :object_name, :part_number, :verb, :url,
          headers: {},
          upload: [:uploader, :upload_id],
          parts: [:ETag, :partNum]
        )
      end
  end
end
