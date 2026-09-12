const SCRIPT = `(function(){try{var t=localStorage.getItem('story.theme');if(t!=='midnight'&&t!=='paper'&&t!=='system'){t='midnight';localStorage.setItem('story.theme',t);}if(t!=='system')document.documentElement.setAttribute('data-theme',t);var r=localStorage.getItem('story.reading');if(r==='large')document.documentElement.setAttribute('data-reading','large');}catch(e){}})();`;

export function ThemeScript() {
  return <script dangerouslySetInnerHTML={{ __html: SCRIPT }} />;
}
