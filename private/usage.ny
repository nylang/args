// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of CommandLineArguments;

pub method(ArgParser) Usage() -> string {
  if self.scopes.IsEmpty() {
    return "";
  }

  var usage = StringBuffer.New();
  let root = self.scopes.Get(0);
  var heading = false;
  var index: int32 = 0;
  while index < root.options.Len() {
    let option = root.options.Get(index);
    if !option.settings.hidden {
      if !heading {
        usage.Append("Options:\n");
        heading = true;
      }

      option.AppendUsage(usage);
    }

    index += 1;
  }

  heading = false;
  index = 1;
  while index < self.scopes.Len() {
    let command = self.scopes.Get(index);
    if command.parent == 0 {
      if !heading {
        if usage.Len() > 0 {
          usage.Append("\n");
        }
        usage.Append("Commands:\n");
        heading = true;
      }

      usage.Append("  ");
      usage.Append(command.name);
      if command.help.length > 0 {
        usage.Append("  ");
        usage.Append(command.help);
      }
      usage.Append("\n");
    }

    index += 1;
  }

  return usage.Take();
}

method(ArgDefinition) AppendUsage(usage: ref mut StringBuffer) -> void {
  usage.Append("  ");
  if self.settings.abbreviation.length > 0 {
    usage.Append("-");
    usage.Append(self.settings.abbreviation);
    usage.Append(", ");
  }
  usage.Append("--");
  if self.negatable {
    usage.Append("[no-]");
  }
  usage.Append(self.name);
  if self.kind != ArgOptionKind.Flag {
    usage.Append(" <");
    usage.Append(self.settings.value_help.length == 0 ? "value" : self.settings.value_help);
    usage.Append(">");
  }
  if self.required {
    usage.Append(" (required)");
  }
  if self.settings.help.length > 0 {
    usage.Append("  ");
    usage.Append(self.settings.help);
  }
  usage.Append("\n");
}
