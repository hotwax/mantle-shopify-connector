<@compress single_line=true>
mutation createCustomer($input: CustomerInput!) {
  customerCreate(input: $input) {
    userErrors {
      field
      message
    }
    customer {
      id
    }
  }
}
</@compress>