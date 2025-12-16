query ($search: String, $after: String) {
  orders(first: 100, after: $after, query: $search) {
    edges {
      node {
        legacyResourceId
        createdAt
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
