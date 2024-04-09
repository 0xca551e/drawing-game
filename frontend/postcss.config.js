export default {
  plugins: {
    "postcss-bem-fix": {
      style: "bem",
      shortcuts: {
        component: "b",
        descendent: "e",
        modifier: "m",
        utility: "u",
        when: "w",
      },
    },
    "postcss-nesting": {},
  },
};
