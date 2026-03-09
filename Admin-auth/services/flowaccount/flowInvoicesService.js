function mapJobToInvoicePayload(job = {}) {
  const today = new Date().toISOString().slice(0, 10);

  const quantity = Number(job.quantity || 1);
  const pricePerUnit = Number(job.pricePerUnit || 0);
  const total = Number(job.total || quantity * pricePerUnit);

  return {
    contactName: job.contactName || job.customerName || "Customer",
    contactAddress: job.contactAddress || "",
    contactTaxId: job.contactTaxId || "",
    contactEmail: job.contactEmail || "",
    contactNumber: job.contactNumber || "",
    publishedOn: job.publishedOn || today,
    dueDate: job.dueDate || today,
    projectName: job.projectName || job.jobNo || "ERP Job",
    reference: job.reference || job.jobNo || "",
    isVatInclusive: Boolean(job.isVatInclusive || false),
    isVat: Boolean(job.isVat || false),
    subTotal: total,
    totalAfterDiscount: total,
    grandTotal: total,
    items: [
      {
        name: job.itemName || "Service Item",
        quantity,
        pricePerUnit,
        total,
        type: 1,
        unitName: job.unitName || "unit",
        description: job.description || "",
      },
    ],
    documentStructureType: "Simple document",
  };
}

module.exports = {
  mapJobToInvoicePayload,
};
