Finds assertion failure in [Harfbuzz](https://github.com/behdad/harfbuzz)

Time to find: several hours. Sample crash file attached.

```
harfbuzz-1.3.2: hb-buffer.cc:419: bool hb_buffer_t::move_to(unsigned int): Assertion `i <= out_len + (len - idx)' failed.
```


