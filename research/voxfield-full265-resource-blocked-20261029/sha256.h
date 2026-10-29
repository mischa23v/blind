// Existing OpenSSL libcrypto only. Link approval and source review required before build.
#pragma once
#include <openssl/sha.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <stdexcept>
inline std::string sha256(const void*data,size_t bytes){unsigned char hash[SHA256_DIGEST_LENGTH];if(!SHA256(static_cast<const unsigned char*>(data),bytes,hash))throw std::runtime_error("SHA256_failed");std::ostringstream o;o<<std::hex<<std::setfill('0');for(auto c:hash)o<<std::setw(2)<<unsigned(c);return o.str();}
inline void sha256Selftests(){
 {auto value=std::string(0,'a');if(sha256(value.data(),value.size())!="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")throw std::runtime_error("SHA256_known_vector_0");}
 {auto value=std::string("abc");if(sha256(value.data(),value.size())!="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")throw std::runtime_error("SHA256_known_vector_3");}
 {auto value=std::string(55,'a');if(sha256(value.data(),value.size())!="9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318")throw std::runtime_error("SHA256_known_vector_55");}
 {auto value=std::string(56,'a');if(sha256(value.data(),value.size())!="b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a")throw std::runtime_error("SHA256_known_vector_56");}
 {auto value=std::string(63,'a');if(sha256(value.data(),value.size())!="7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34")throw std::runtime_error("SHA256_known_vector_63");}
 {auto value=std::string(64,'a');if(sha256(value.data(),value.size())!="ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb")throw std::runtime_error("SHA256_known_vector_64");}
 {auto value=std::string(65,'a');if(sha256(value.data(),value.size())!="635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0")throw std::runtime_error("SHA256_known_vector_65");}
 {auto value=std::string(128,'a');if(sha256(value.data(),value.size())!="6836cf13bac400e9105071cd6af47084dfacad4e5e302c94bfed24e013afb73e")throw std::runtime_error("SHA256_known_vector_128");}
 {auto value=std::string(1000000,'a');if(sha256(value.data(),value.size())!="cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")throw std::runtime_error("SHA256_known_vector_1000000");}
}
