import java
module FileTaints{
private import semmle.code.java.dataflow.FlowSources
 
class PreserveGetName extends TaintPreservingCallable {
  PreserveGetName() { this.getName() = "getName" }

  override predicate returnsTaintFrom(int arg) { arg = -1 }
}
}