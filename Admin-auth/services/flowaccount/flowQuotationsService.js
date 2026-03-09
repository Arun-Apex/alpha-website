function mapJobToQuotationPayload(job = {}) {
  const today = new Date().toISOString().slice(0, 10);

  const items = Array.isArray(job.items) && job.items.length
    ? job.items.map((item) => ({
        name: item.name || "Service Item",
        quantity: Number(item.quantity || 1),
        pricePerUnit: Number(item.pricePerUnit || 0),
        total: Number(item.total || (Number(item.quantity || 1) * Number(item.pricePerUnit || 0))),
        type: Number(item.type || 1),
        unitName: item.unitName || "unit",
        description: item.description || "",
      }))
    : [
        {
          name: job.itemName || "Service Item",
          quantity: Number(job.quantity || 1),
          pricePerUnit: Number(job.pricePerUnit || 0),
          total: Number(job.total || (Number(job.quantity || 1) * Number(job.pricePerUnit || 0))),
          type: 1,
          unitName: "unit",
          description: job.description || "",
        },
      ];

  const subTotal = items.reduce((sum, item) => sum + Number(item.total || 0), 0);

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
    subTotal,
    totalAfterDiscount: subTotal,
    grandTotal: subTotal,
    items,
    documentStructureType: "Simple document",
  };
}

module.exports = {
  mapJobToQuotationPayload,
};
