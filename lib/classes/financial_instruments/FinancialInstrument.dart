/// Define enumerator to classify the financial instrument
/// by the provider offering the service
enum FinancialInstrumentProvider{
  financialInstitution("Istituto finanziaro"),
  publicInstitution("Istituzione pubblica");

  /* define constants */
  final String name;

  /* define constructor */
  const FinancialInstrumentProvider(this.name);
}