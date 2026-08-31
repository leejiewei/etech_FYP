// Simple FAQ accordion, shared by info.html and service.html.
function toggleFaq(button) {
  button.parentElement.classList.toggle("open");
}

// Enquiry form on contact.html — no real backend, just shows a confirmation.
function submitEnquiry(event) {
  event.preventDefault();
  document.getElementById("enquiry-form").style.display = "none";
  document.getElementById("enquiry-confirmation").style.display = "block";
}
