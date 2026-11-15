// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of CommandLineArguments;

pub struct ArgToken {
  raw: string;
  following: string;
  equals: int32;
  index: int32;
  has_following: bool;
}

pub static method(ArgToken) At(arguments: ref <string>[], index: int32) -> ArgToken {
  let token: string = arguments[index];
  let has_following: bool = index + 1 < arguments.length;

  return ArgToken{
    raw: token, following: has_following ? arguments[index + 1] : "",
    equals: token.FindByte('='), index: index, has_following: has_following
  };
}

pub method(ArgToken) Raw() -> string {
  return self.raw;
}

pub method(ArgToken) Index() -> int32 {
  return self.index;
}

pub method(ArgToken) Name() -> string {
  if self.HasAttachedValue() {
    return self.raw.Slice(0, self.equals);
  }

  return self.raw;
}

pub method(ArgToken) IsOption({ bare_dash: bool = false }) -> bool {
  return self.raw.StartsWith("-") && (self.raw.length > 1 || bare_dash);
}

pub method(ArgToken) IsDelimiter() -> bool {
  return self.raw == "--";
}

pub method(ArgToken) Matches(spelling: ref string) -> bool {
  if self.HasAttachedValue() {
    return self.equals == spelling.length && self.raw.StartsWith(spelling);
  }

  return self.raw == spelling;
}

pub method(ArgToken) HasAttachedValue() -> bool {
  return self.equals >= 0;
}

pub method(ArgToken) HasFollowing() -> bool {
  return self.has_following;
}

pub method(ArgToken) HasValue() -> bool {
  return self.HasAttachedValue() || self.HasFollowing();
}

pub method(ArgToken) Value() -> string {
  if self.HasAttachedValue() {
    return self.raw.Slice(self.equals + 1, self.raw.length);
  }

  return self.following;
}

pub method(ArgToken) AfterValue() -> int32 {
  return self.index + (self.HasAttachedValue() ? 1 : 2);
}
