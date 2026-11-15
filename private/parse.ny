// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of CommandLineArguments;

struct ArgMatch {
  level: int32;
  option: int32;
  negated: bool;
}

// Matches one argv token at a time. The selected scopes are both the lookup
// chain for global options and the owner of all partially parsed values.
struct ArgCursor {
  next: int32;
  stop: bool;
  scopes: Array<ArgResultScope>;
}

pub method(ArgParser) ParseArgv(arguments: ref <string>[]) -> Result<ArgResults, ArgError> {
  return self.Parse(arguments, start: arguments.length == 0 ? 0 : 1);
}

pub method(ArgParser) Parse(arguments: ref <string>[], { start: int32 = 0 }) -> Result<ArgResults, ArgError> {
  if start < 0 || start > arguments.length {
    return ArgError{kind: ArgErrorKind.InvalidStart, index: start, message: "start is outside the argument array"};
  }
  if self.scopes.IsEmpty() {
    return ArgDefinition.Error(ArgErrorKind.InvalidDefinition, "", "create the parser with ArgParser.New");
  }

  var cursor = ArgCursor{next: start, scopes: Array<ArgResultScope>.New()};
  cursor.scopes.Push(ArgResultScope.New(0, self.scopes.Get(0)));
  while cursor.next < arguments.length {
    let taken = cursor.Take(self, arguments);
    if taken != nil {
      return taken!;
    }
  }

  let missing = cursor.CheckRequired(self);
  if missing != nil {
    return missing!;
  }

  return ArgResults{scopes: cursor.scopes};
}

method(ArgCursor) Take(parser: ref ArgParser, arguments: ref <string>[]) -> ArgError? {
  let index = self.next;
  let token: string = arguments[index];
  self.next += 1;
  let level = self.scopes.Len() - 1;
  if !self.stop {
    if token == "--" {
      self.stop = true;
      return nil;
    }
    if token.StartsWith("--") {
      return self.TakeLong(parser, arguments, token, index);
    }
    if token.length > 1 && token[0] == '-' {
      return self.TakeShort(parser, arguments, token, index);
    }

    let scope_id = self.scopes.Get(level).scope_id;
    if self.scopes.Get(level).rest.IsEmpty() {
      let child = parser.FindCommand(scope_id, token);
      if child >= 0 {
        self.scopes.Push(ArgResultScope.New(child, parser.scopes.Get(child)));
        return nil;
      }
    }

    self.stop = !parser.scopes.Get(scope_id).trailing;
  }

  self.scopes.GetMut(level).rest.Push(copy(token));
  return nil;
}

method(ArgCursor) TakeLong(
  parser: ref ArgParser, arguments: ref <string>[], token: ref string, index: int32
) -> ArgError? {
  let equals = token.FindByte('=');
  let end = equals < 0 ? token.length : equals;
  let name = token.View(2, end - 2);
  let selected = self.Match(parser, name, false);
  if selected.option < 0 {
    return self.Error(ArgErrorKind.UnknownOption, index, name, self.scopes.Len() - 1, "unknown option");
  }

  var attached: string? = nil;
  if equals >= 0 {
    attached = token.View(equals + 1, token.length - equals - 1);
  }

  return self.Apply(parser, arguments, selected, attached, index);
}

method(ArgCursor) TakeShort(
  parser: ref ArgParser, arguments: ref <string>[], token: ref string, index: int32
) -> ArgError? {
  var offset: int32 = 1;
  while offset < token.length {
    if !ArgDefinition.IsLetterOrDigit(token[offset]) {
      return self.Error(ArgErrorKind.UnknownOption, index, token, self.scopes.Len() - 1, "invalid short option");
    }

    let name = token.View(offset, 1);
    let selected = self.Match(parser, name, true);
    if selected.option < 0 {
      return self.Error(ArgErrorKind.UnknownOption, index, name, self.scopes.Len() - 1, "unknown short option");
    }

    offset += 1;
    let kind = self.Definition(parser, selected).kind;
    if kind != ArgOptionKind.Flag {
      var attached: string? = nil;
      if offset < token.length {
        let start = token[offset] == '=' ? offset + 1 : offset;
        attached = token.View(start, token.length - start);
      }

      return self.Apply(parser, arguments, selected, attached, index);
    }
    if offset < token.length && token[offset] == '=' {
      return self.Error(ArgErrorKind.UnexpectedValue, index, name, selected.level, "flag does not take a value");
    }

    self.SetFlag(selected);
  }

  return nil;
}

method(ArgCursor) Match(parser: ref ArgParser, name: ref string, short_name: bool) -> ArgMatch {
  var level = self.scopes.Len() - 1;
  while level >= 0 {
    let definition = parser.scopes.Get(self.scopes.Get(level).scope_id);
    if short_name {
      let option = definition.FindShort(name[0]);
      if option >= 0 {
        return ArgMatch{level: level, option: option};
      }
    } else {
      let matched = definition.FindLong(name);
      if matched.index >= 0 {
        return ArgMatch{level: level, option: matched.index, negated: matched.negated};
      }
    }

    level -= 1;
  }

  return ArgMatch{option: -1};
}

method(ArgCursor) Definition(parser: ref ArgParser, selected: ref ArgMatch) -> ArgDefinition {
  return parser.scopes.Get(self.scopes.Get(selected.level).scope_id).options.Get(selected.option);
}

method(ArgCursor) SetFlag(selected: ref ArgMatch) -> void {
  self.scopes.GetMut(selected.level).options.GetMut(selected.option).flag = !selected.negated;
  self.scopes.GetMut(selected.level).options.GetMut(selected.option).parsed = true;
}

method(ArgCursor) Apply(
  parser: ref ArgParser, arguments: ref <string>[], selected: ref ArgMatch, attached: string?, index: int32
) -> ArgError? {
  let definition = self.Definition(parser, selected);
  if definition.kind == ArgOptionKind.Flag {
    if attached != nil {
      return self.Error(ArgErrorKind.UnexpectedValue, index, definition.name, selected.level, "flag does not take a value");
    }

    self.SetFlag(selected);
    return nil;
  }

  var text: string = "";
  if attached != nil {
    text = attached!;
  } else {
    if self.next >= arguments.length || arguments[self.next] == "--" {
      return self.Error(ArgErrorKind.MissingValue, index, definition.name, selected.level, "option needs a value");
    }

    text = arguments[self.next];
    self.next += 1;
  }
  if !self.scopes.GetMut(selected.level).options.GetMut(selected.option).SetText(definition, text) {
    return self.Error(ArgErrorKind.InvalidValue, index, definition.name, selected.level, "value is outside the allowed set");
  }

  return nil;
}

method(ArgCursor) CheckRequired(parser: ref ArgParser) -> ArgError? {
  var level: int32 = 0;
  while level < self.scopes.Len() {
    let result = self.scopes.Get(level);
    let definition = parser.scopes.Get(result.scope_id);
    var index: int32 = 0;
    while index < definition.options.Len() {
      let option = definition.options.Get(index);
      if option.required && !result.options.Get(index).parsed {
        return self.Error(ArgErrorKind.MissingOption, -1, option.name, level, "required option is missing");
      }

      index += 1;
    }

    level += 1;
  }

  return nil;
}

method(ArgCursor) Error(kind: ArgErrorKind, index: int32, option: ref string, level: int32, message: ref string) -> ArgError {
  let description = option.length == 0 ? copy(message) : message.Concat(" (").Concat(option).Concat(")");
  return ArgError{
    kind: kind, index: index, option: copy(option), command: self.scopes.Get(level).name, message: description
  };
}
