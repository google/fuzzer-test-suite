#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/stat.h>
#include <wolfssl/ssl.h>

#ifndef CERT_PATH
# define CERT_PATH
#endif


static int read_file(const char *fn, unsigned char **buf)
{
    struct stat file_status;
    FILE *fp;

    if (stat(fn, &file_status) != 0) {
      printf("Error on `stat` over %s\n", fn);
      perror("ERROR: Could not stat or file does not exist");
    }

    if ((fp = fopen(fn, "r")) == NULL)
        return -1;

    *buf = (unsigned char *)malloc(file_status.st_size);
    if (!fread(*buf, file_status.st_size, 1, fp)) {
        perror("ERROR: Could not read file");
        free(*buf);
        return -1;
    }

    fclose(fp);
    return file_status.st_size;
}

static int verify_cert_mem(const uint8_t *certfile, uint32_t size_cert,
                           const uint8_t *cafile, uint32_t size_ca)
{
    int ret = -1;
    int filetype = SSL_FILETYPE_PEM;

    WOLFSSL_CERT_MANAGER *cm = NULL;

    ret = wolfSSL_Init();
    if (ret != SSL_SUCCESS)
        goto out;


    cm = wolfSSL_CertManagerNew();
    if (cm == NULL) {
        return EXIT_FAILURE;
    }

    ret = wolfSSL_CertManagerLoadCABuffer(cm,
                                          cafile,
                                          size_ca,
                                          filetype);

    if (ret != SSL_SUCCESS) {
        goto out;
    }

    ret = wolfSSL_CertManagerVerifyBuffer(cm,
                                          certfile,
                                          size_cert,
                                          filetype);
    if (ret != SSL_SUCCESS) {
        goto out;
    }

    ret = 0;

out:
    wolfSSL_CertManagerUnloadCAs(cm);
    wolfSSL_CertManagerFree(cm);
    wolfSSL_Cleanup();
    return ret;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *cert_data,
                                      size_t cert_sz) {
    uint8_t *ca_data = NULL;
    size_t ca_sz;

    if ((ca_sz = read_file(CERT_PATH "certs/ca.pem", &ca_data)) == -1) {
        goto end;
    }

    verify_cert_mem(cert_data, cert_sz, ca_data, ca_sz);

end:
    if (ca_data) {
        free(ca_data);
        ca_data = NULL;
    }
    return 0;
}
