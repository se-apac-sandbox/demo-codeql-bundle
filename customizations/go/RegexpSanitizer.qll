import go

module loggingSanitizer{
    private import semmle.go.security.LogInjection

    class RegexpSanitizer extends LogInjection::Sanitizer {
        RegexpSanitizer() {
          exists(DataFlow::CallNode call |
            this = call and
            call.getTarget().getName() = ["ReplaceAllString", "ReplaceAllLiteralString"] and
            call.getReceiver() =
              any(RegexpPattern rp | rp.getPattern().matches("%" + ["\\r", "\\n"] + "%")).getAUse()
          )
        }
      }
    
}
