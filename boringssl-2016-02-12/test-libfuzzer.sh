#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Note: this target contains unbalanced malloc/free (malloc is called
# in one invocation, free is called in another invocation).
# and so libFuzzer's -detect_leaks should be disabled for better speed.

echo "Not implemented yet, the bug takes several hours of fuzzing to find"
