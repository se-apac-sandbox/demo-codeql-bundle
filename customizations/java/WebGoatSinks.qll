import java

module WebGoatSinks{
private import semmle.code.java.dataflow.FlowSteps
private import semmle.code.java.security.XSS


class WebgoatSink extends XssSink {
WebgoatSink() {
  this.asExpr()
  .(Argument)
  .getCall()
  .getCallee()
  .hasQualifiedName("org.owasp.webgoat.assignments", "AttackResult$AttackResultBuilder",
  ["output", "outputArgs", "feedback", "feedbackArgs"])
}}
}