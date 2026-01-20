# frozen_string_literal: true

require 'openssl'
require 'digest'

module Tapo
  class KlapCipher
    attr_reader :seq

    # @param local_seed [String] 16-byte local seed
    # @param remote_seed [String] 16-byte remote seed from device
    # @param auth_hash [String] 32-byte authentication hash
    def initialize(local_seed, remote_seed, auth_hash)
      combined = local_seed + remote_seed + auth_hash

      # Derive encryption key (16 bytes)
      @key = Digest::SHA256.digest('lsk' + combined)[0, 16]

      # Derive IV base (12 bytes) and initial sequence number
      iv_hash = Digest::SHA256.digest('iv' + combined)
      @iv_base = iv_hash[0, 12]
      @seq = iv_hash[-4..-1].unpack1('N').to_i

      # Derive signature key (28 bytes)
      @signature_key = Digest::SHA256.digest('ldk' + combined)[0, 28]
    end

    # @param plaintext [String] The plaintext to encrypt
    # @return [Array<String, Integer>] Encrypted payload (signature + ciphertext) and sequence number
    def encrypt(plaintext)
      @seq += 1

      # Create message-specific IV
      iv = @iv_base + [@seq].pack('N')

      # Encrypt with AES-128-CBC
      cipher = OpenSSL::Cipher.new('AES-128-CBC')
      cipher.encrypt
      cipher.key = @key
      cipher.iv = iv
      cipher.padding = 1 # PKCS7 padding

      ciphertext = cipher.update(plaintext) + cipher.final

      # Create signature
      signature = Digest::SHA256.digest(@signature_key + [@seq].pack('N') + ciphertext)

      [signature + ciphertext, @seq]
    end

    # @param encrypted_data [String] The encrypted data (signature + ciphertext)
    # @param seq [Integer] The sequence number used for this message
    # @return [String] Decrypted plaintext
    def decrypt(encrypted_data, seq)
      # Skip signature (first 32 bytes) and decrypt the rest
      ciphertext = encrypted_data[32..-1]

      # Create message-specific IV
      iv = @iv_base + [seq].pack('N')

      # Decrypt with AES-128-CBC
      decipher = OpenSSL::Cipher.new('AES-128-CBC')
      decipher.decrypt
      decipher.key = @key
      decipher.iv = iv
      decipher.padding = 1 # PKCS7 padding

      decipher.update(ciphertext) + decipher.final
    end
  end
end
