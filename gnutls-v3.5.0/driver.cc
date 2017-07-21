#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/stat.h>
#include <assert.h>

#include <gnutls/gnutls.h>
#include <gnutls/x509.h>
#include <gnutls/pkcs11.h>

#define DBG(...) do {printf(__VA_ARGS__); fflush(stdout);} while (0)
const static char *CAPATH_DEFAULT1   = "/etc/ssl/certs";

static int read_file(const char *fn, unsigned char **buf)
{
    struct stat file_status;
    FILE *fp;

    if (stat(fn, &file_status) != 0)
        perror("ERROR: Could not stat or file does not exist");

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

struct GlobalState {
    GlobalState()
    : list(InitCaStore()){
            int ret = -1;
            ret =  gnutls_global_init();
            assert (ret >= 0);
    }

    ~GlobalState() {
            gnutls_x509_trust_list_deinit(list, 1);
            gnutls_global_deinit();
    }

    gnutls_x509_trust_list_t InitCaStore() {
            gnutls_x509_trust_list_t list;
            int ret = -1;
            ret = gnutls_x509_trust_list_init(&list, 0);
            assert (ret >= 0);

            ret = gnutls_x509_trust_list_add_trust_dir(list,
                                                       CAPATH_DEFAULT1,
                                                       NULL,
                                                       GNUTLS_X509_FMT_PEM,
                                                       0,
                                                       0);
            assert (ret >= 0);
            return list;
    }

    // Global CA store
    gnutls_x509_trust_list_t list;
};

int
print_details_func(gnutls_x509_crt_t cert,
                   gnutls_x509_crt_t issuer, gnutls_x509_crl_t crl,
                   unsigned int verification_output)
{
        char name[512];
        char issuer_name[512];
        size_t name_size;
        size_t issuer_name_size;

        issuer_name_size = sizeof(issuer_name);
        gnutls_x509_crt_get_issuer_dn(cert, issuer_name,
                                      &issuer_name_size);

        name_size = sizeof(name);
        gnutls_x509_crt_get_dn(cert, name, &name_size);

        if (issuer != NULL) {
                issuer_name_size = sizeof(issuer_name);
                gnutls_x509_crt_get_dn(issuer, issuer_name,
                                       &issuer_name_size);

                DBG("\tVerified against: %s\n", issuer_name);
        }

        if (crl != NULL) {
                issuer_name_size = sizeof(issuer_name);
                gnutls_x509_crl_get_issuer_dn(crl, issuer_name,
                                              &issuer_name_size);

                DBG("\tVerified against CRL of: %s\n",
                        issuer_name);
        }

        return 0;
}

int
verify_certificate_chain(gnutls_x509_trust_list_t tlist,
                         const char *hostname,
                         gnutls_x509_crt_t * cert,
                         int cert_chain_length)
{
        unsigned int output = 1;


        /* if this certificate is not explicitly trusted verify against CAs
         */
        if (output != 0) {
          gnutls_x509_trust_list_verify_crt(tlist, cert,
                                            cert_chain_length, 0,
                                            &output,
                                            print_details_func);
        }



        if (output & GNUTLS_CERT_INVALID) {
                DBG("Not trusted\n");
#ifdef CONFIG_DEBUG
                gnutls_datum_t txt;
                gnutls_certificate_verification_status_print(output,
                                                             GNUTLS_CRT_X509,
                                                             &txt, 0);

                DBG("Error: %s\n", txt.data);
                gnutls_free(txt.data);
#endif
        } else
                DBG("Trusted\n");


        return output;
}

int verify_cert_mem(const uint8_t *cert, uint32_t cert_size)
{
    int ret;
    unsigned i;
    gnutls_datum_t cert_tmp = {NULL , 0};
    gnutls_x509_crt_t *x509_cert_list = NULL;
    unsigned int x509_ncerts = 0;
    unsigned vflags;
    gnutls_x509_crt_fmt_t outformat;
    unsigned int output = -1;

    static GlobalState g_state;

    DBG("\n[+] ---[ GnuTLS (PEM) ]---\n");
    outformat = GNUTLS_X509_FMT_PEM;

    cert_tmp.data = (unsigned char *) cert;
    cert_tmp.size = cert_size;

    /* ignore errors. CRLs might not be given */
    ret = gnutls_x509_crt_list_import2(&x509_cert_list,
                                       &x509_ncerts,
                                       &cert_tmp,
                                       outformat,
                                       0);
    if (ret < 0 || x509_ncerts < 1) {
        DBG("error parsing CRTs: %s\n", gnutls_strerror(ret));
        output = ret;
        goto exit2;
    }

    DBG("Loaded %d certificates\n\n", x509_ncerts);

    vflags = GNUTLS_VERIFY_DO_NOT_ALLOW_SAME;

    ret = verify_certificate_chain(g_state.list,
                                   "dummy_no_hostname",
                                   x509_cert_list,
                                   x509_ncerts);

exit2:
    for (i = 0; i < x509_ncerts; i++)
        gnutls_x509_crt_deinit(x509_cert_list[i]);
    if (x509_cert_list)
        gnutls_free(x509_cert_list);

    DBG("gnutls_x509_trusted_list_verify_crt: %s\n", gnutls_strerror(ret));
    return ret;
}


static void test(char *cert)
{
    int ret = -1;

    uint8_t *cert_data = NULL;
    size_t cert_sz;

    if ((cert_sz = read_file(cert, &cert_data)) == -1) {
        printf("ERROR reading file: %s\n", cert);
        goto end;
    }

    ret = verify_cert_mem(cert_data, cert_sz);
    printf("ret: %d\n", ret);

end:
    if (cert_data) {
        free(cert_data);
        cert_data = NULL;
    }
    return;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        printf("usage: %s <certificate>\n", argv[0]);
        return EXIT_SUCCESS;
    }

    test(argv[1]);

    return EXIT_SUCCESS;
}
