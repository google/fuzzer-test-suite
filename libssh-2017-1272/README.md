This is a benchmark for finding a
[memory leak bug](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=1272) in
[libssh](https://www.libssh.org).

The following error can be found in about 2 minutes of fuzzing.

```
ERROR: LeakSanitizer: detected memory leaks

Direct leak of 1 byte(s) in 1 object(s) allocated from:
    #0 0x4bf8ea in calloc 
    #1 0x5048f7 in ssh_packet_userauth_info_response src/messages.c:1001:30
    #2 0x51237d in ssh_packet_process src/packet.c:451:5
    #3 0x511c40 in ssh_packet_socket_callback src/packet.c:332:13
    #4 0x5263ad in ssh_socket_pollcallback src/socket.c:298:25
    #5 0x5c93c0 in ssh_poll_ctx_dopoll src/poll.c:632:27
    #6 0x524a62 in ssh_handle_packets src/session.c:634:10
    #7 0x52452b in ssh_handle_packets_termination src/session.c:696:15
    #8 0x55810d in ssh_handle_key_exchange src/server.c:589:10
    #9 0x4ed2cd in LLVMFuzzerTestOneInput
```
