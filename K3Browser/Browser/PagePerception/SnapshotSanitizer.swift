import Foundation

enum SnapshotSanitizer {
    static func sanitizedURL(_ raw: String) -> String {
        Redactor.sanitizeURLString(raw)
    }

    static func sanitizedMetadata(_ raw: String) -> String {
        Redactor.text(raw)
    }

    static let javascript = """
    (function(){
      function clean(s){return (s||'').replace(/\\s+/g,' ').trim();}
      function cssPath(el){
        if(!el || !el.tagName) return '';
        if(el.id && /^[A-Za-z][A-Za-z0-9_-]*$/.test(el.id)) return '#'+el.id;
        if(el.name) return el.tagName.toLowerCase()+'[name="'+CSS.escape(el.name)+'"]';
        var path=[];
        while(el && el.nodeType===1 && el!==document.body){
          var name=el.tagName.toLowerCase();
          var parent=el.parentElement;
          if(parent){ var same=Array.prototype.filter.call(parent.children,function(x){return x.tagName===el.tagName;}); if(same.length>1){ name+=':nth-of-type('+(same.indexOf(el)+1)+')'; } }
          path.unshift(name); el=parent;
        }
        return path.join(' > ');
      }
      function visible(el){ var r=el.getBoundingClientRect(); var st=getComputedStyle(el); return r.width>0 && r.height>0 && st.visibility!=='hidden' && st.display!=='none'; }
      function elem(el){ return {selector:cssPath(el), tag:(el.tagName||'').toLowerCase(), text:clean(el.innerText||el.getAttribute('aria-label')||'').slice(0,160), ariaLabel:clean(el.getAttribute('aria-label')||''), role:clean(el.getAttribute('role')||''), type:clean(el.getAttribute('type')||''), name:clean(el.getAttribute('name')||''), placeholder:clean(el.getAttribute('placeholder')||''), isVisible:visible(el)}; }
      function isHiddenField(el){return (el.getAttribute('type')||'').toLowerCase()==='hidden';}
      function fieldInfo(x){
        var typ=(x.getAttribute('type')||x.tagName||'').toLowerCase();
        var label=clean((x.labels&&x.labels[0]&&x.labels[0].innerText)||'');
        var metadata=[typ,x.name||'',x.autocomplete||'',label,x.getAttribute('aria-label')||'',x.placeholder||''].join(' ').toLowerCase();
        var sensitive=/(password|passcode|passwd|secret|token|otp|one-time|2fa|credit.?card|card.?number|cvv|cvc|security.?code|private.?key|mnemonic|seed)/.test(metadata);
        return {selector:cssPath(x), tag:(x.tagName||'').toLowerCase(), type:typ, name:clean(x.name||''), label:label, placeholder:clean(x.placeholder||''), valuePreview:sensitive?'[masked]':'[not captured]', required:!!x.required};
      }
      var headings=Array.from(document.querySelectorAll('h1,h2,h3')).filter(visible).slice(0,40).map(elem);
      var buttons=Array.from(document.querySelectorAll('button,[role=button],input[type=button],input[type=submit],a')).filter(visible).slice(0,80).map(elem);
      var inputs=Array.from(document.querySelectorAll('input,textarea,select')).filter(function(x){return visible(x)&&!isHiddenField(x);}).slice(0,80).map(elem);
      var links=Array.from(document.querySelectorAll('a[href]')).filter(visible).slice(0,100).map(function(a){return {text:clean(a.innerText||a.getAttribute('aria-label')||a.href).slice(0,160), href:a.href, selector:cssPath(a)};});
      var forms=Array.from(document.querySelectorAll('form')).slice(0,20).map(function(f){return {selector:cssPath(f), action:f.action||'', method:f.method||'', fields:Array.from(f.querySelectorAll('input,textarea,select')).filter(function(x){return !isHiddenField(x);}).slice(0,60).map(fieldInfo)};});
      var tables=Array.from(document.querySelectorAll('table')).slice(0,12).map(function(t){var rows=Array.from(t.querySelectorAll('tr')).slice(0,30).map(function(r){return Array.from(r.querySelectorAll('th,td')).slice(0,12).map(function(c){return clean(c.innerText).slice(0,120);});}); var headers=rows.length?rows[0]:[]; return {selector:cssPath(t), headers:headers, rows:rows.slice(1)};});
      return JSON.stringify({title:document.title||'', url:location.href, text:clean(document.body?document.body.innerText:'').slice(0,18000), headings:headings, buttons:buttons, inputs:inputs, links:links, forms:forms, tables:tables});
    })();
    """
}
