# Your prompt library. Each prompt is either a plain attrset or a function
# from arguments (all with defaults) to an attrset — full Nix templating.
{
  code-review = import ./code-review.nix;

  style-instructions = {
    type = "instructions";
    name = "style";
    body = ''
      ## Style

      Prefer small, focused commits with descriptive messages.
    '';
  };
}
