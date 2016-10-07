Finds a debug print and a 8-byte-write-heap-buffer-overflow in [RE2](https://github.com/google/re2).

Time to find: < 10 seconds.
```
re2/dfa.cc:459: DFA out of memory: prog size 61280 mem 2550862
```

Time to find: < 1 hour.
```
==19481==ERROR: AddressSanitizer: heap-buffer-overflow
WRITE of size 8 at 0x60200146a188 thread T0
    #0 0x568f9a in re2::NFA::Search(re2::StringPiece const&, re2::StringPiece const&, bool, bool, re2::StringPiece*, int) re2/nfa.cc:532:31
    #1 0x5695cb in re2::Prog::SearchNFA(re2::StringPiece const&, re2::StringPiece const&, re2::Prog::Anchor, re2::Prog::MatchKind, re2::StringPiece*, int) re2/nfa.cc:701:12
    #2 0x4fde7a in re2::RE2::Match(re2::StringPiece const&, int, int, re2::RE2::Anchor, re2::StringPiece*, int) const re2/re2.cc:768:19
    #3 0x4f9110 in re2::RE2::DoMatch(re2::StringPiece const&, re2::RE2::Anchor, int*, re2::RE2::Arg const* const*, int) const re2/re2.cc:817:8
    #4 0x4ef56a in re2::VariadicFunction2<bool, re2::StringPiece const&, re2::RE2 const&, re2::RE2::Arg, &re2::RE2::FullMatchN>::operator()(re2::StringPiece const&, re2::RE2 const&) const re2/variadic_function.h:15:12
```


