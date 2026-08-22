import { defineConfig, HeadConfig } from 'vitepress'

const umamiScript: HeadConfig = ["script", {
  defer: "true",
  src: "https://bul0hfxshyzutcdjwmaygdib.service.bsws.in/script.js",
  "data-website-id": "218292fe-7665-4031-a754-5b942fa27685"
}]

const baseHeaders: HeadConfig[] = [['link', { rel: 'icon', href: '/vono.svg' }]]

const headers = process.env.NODE_ENV === "production" ?
  [...baseHeaders, umamiScript] :
  baseHeaders

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Vono - Web framework inspired by Hono",
  description: "Hono but in Vlang",
  head: headers,
  themeConfig: {
  logo:"/vono.svg",
  siteTitle: "Vono",
  search: {
      provider: 'local',
    },

    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Gettings Started', link: '/getting-started' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Motivation', link: '/motivation' },
          { text: 'Gettings Started', link: '/getting-started' },
          // { text: 'Markdown Examples', link: '/markdown-examples' },
          // { text: 'Runtime API Examples', link: '/api-examples' },
        ]
      },
      {
        text: 'Middleware',
        items: [
          { text: 'Middleware', link: '/middleware' },
          // { text: 'Gettings Started', link: '/getting-started' },
          // { text: 'Markdown Examples', link: '/markdown-examples' },
          // { text: 'Runtime API Examples', link: '/api-examples' },
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/shishantbiswas/vono' }
    ]
  }
})
