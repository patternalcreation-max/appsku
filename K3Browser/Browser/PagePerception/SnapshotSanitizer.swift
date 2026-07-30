import Foundation

enum SnapshotSanitizer {
    static func sanitizedURL(_ raw: String) -> String {
        Redactor.sanitizeURLString(raw)
    }

    static func sanitizedMetadata(_ raw: String) -> String {
        Redactor.text(raw)
    }

    static let javascript = #"""
    return (function(){
      "use strict";
      if(typeof snapshotBinding!=="string"||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/u.test(snapshotBinding))throw new TypeError("Invalid snapshot binding");
      globalThis.__K3BrowserPrivateSnapshotDocumentBinding_8f6d2a41=snapshotBinding;
      const encoder=new TextEncoder();
      function bytePrefix(value,maximum){let output='';let count=0;for(const scalar of String(value)){const width=encoder.encode(scalar).length;if(count+width>maximum)break;output+=scalar;count+=width;}return output;}
      function normalize(value,maximum){let output='';let pendingSpace=false;for(const scalar of String(value==null?'':value)){const cp=scalar.codePointAt(0);const whitespace=(cp>=0x0009&&cp<=0x000d)||cp===0x0020||cp===0x00a0||cp===0x1680||(cp>=0x2000&&cp<=0x200a)||cp===0x2028||cp===0x2029||cp===0x202f||cp===0x205f||cp===0x3000||cp===0xfeff;if(whitespace){pendingSpace=output.length!==0;}else{if(pendingSpace)output+=' ';output+=scalar;pendingSpace=false;}}return bytePrefix(output,maximum);}
      function asciiLowercase(value){return String(value).replace(/[A-Z]/g,function(c){return String.fromCharCode(c.charCodeAt(0)+32);});}
      function cssPath(el){
        if(!el||!el.tagName)return '';
        if(el.id&&/^[A-Za-z][A-Za-z0-9_-]*$/.test(el.id))return '#'+el.id;
        if(el.name&&typeof CSS!=='undefined'&&typeof CSS.escape==='function')return el.tagName.toLowerCase()+'[name="'+CSS.escape(el.name)+'"]';
        const path=[];
        while(el&&el.nodeType===1&&el!==document.body){let name=el.tagName.toLowerCase();const parent=el.parentElement;if(parent){const same=Array.prototype.filter.call(parent.children,function(x){return x.tagName===el.tagName;});if(same.length>1)name+=':nth-of-type('+(same.indexOf(el)+1)+')';}path.unshift(name);el=parent;}
        return path.join(' > ');
      }
      function executableSelector(el){const selector=cssPath(el);if(!selector||encoder.encode(selector).length>4096)return '';try{return document.querySelector(selector)===el?selector:'';}catch(_){return '';}}
      function visible(el){const r=el.getBoundingClientRect();const st=getComputedStyle(el);return r.width>0&&r.height>0&&st.visibility!=='hidden'&&st.display!=='none';}
      function canonicalFormAction(form){if(!form)return '';try{const parsed=new URL(form.action||location.href,location.href);if(parsed.protocol!=='http:'&&parsed.protocol!=='https:')return '__invalid__';if(parsed.username||parsed.password||parsed.port||!parsed.hostname||/[\s\\]/u.test(parsed.hostname))return '__invalid__';return normalize(parsed.href,4096);}catch(_){return '__invalid__';}}
      function elem(el){
        const form=el.tagName&&el.tagName.toLowerCase()==='form'?el:(el.closest?el.closest('form'):null);
        const aria=normalize(el.getAttribute('aria-label')||'',512);
        const associated=normalize((el.labels&&el.labels[0]&&el.labels[0].innerText)||'',512);
        return {
          selector:executableSelector(el),
          tag:asciiLowercase(normalize(el.tagName||'',64)),
          text:normalize((el.innerText||el.getAttribute('aria-label')||'').slice(0,160),2048),
          ariaLabel:aria,
          label:associated,
          role:asciiLowercase(normalize(el.getAttribute('role')||'',128)),
          type:asciiLowercase(normalize(el.getAttribute('type')||'',64)),
          name:normalize(el.getAttribute('name')||'',256),
          placeholder:asciiLowercase(normalize(el.getAttribute('placeholder')||'',512)),
          autocomplete:asciiLowercase(normalize(el.getAttribute('autocomplete')||'',256)),
          isVisible:visible(el),
          formMethod:form?asciiLowercase(normalize(form.method||'',16)):'',
          formAction:canonicalFormAction(form)
        };
      }
      function isHiddenField(el){return asciiLowercase(normalize(el.getAttribute('type')||'',64))==='hidden';}
      function fieldInfo(el){const info=elem(el);info.required=!!el.required;return info;}
      const headings=Array.from(document.querySelectorAll('h1,h2,h3')).filter(visible).slice(0,40).map(elem);
      const buttons=Array.from(document.querySelectorAll('button,[role=button],input[type=button],input[type=submit],a')).filter(visible).slice(0,80).map(elem);
      const inputs=Array.from(document.querySelectorAll('input,textarea,select')).filter(function(el){return visible(el)&&!isHiddenField(el);}).slice(0,80).map(elem);
      const links=Array.from(document.querySelectorAll('a[href]')).filter(visible).slice(0,100).map(function(el){const info=elem(el);info.href=el.href;return info;});
      const forms=Array.from(document.querySelectorAll('form')).slice(0,20).map(function(form){const info=elem(form);info.action=canonicalFormAction(form);info.method=asciiLowercase(normalize(form.method||'',16));info.fields=Array.from(form.querySelectorAll('input,textarea,select')).filter(function(el){return !isHiddenField(el);}).slice(0,60).map(fieldInfo);return info;});
      const tables=Array.from(document.querySelectorAll('table')).slice(0,12).map(function(table){const rows=Array.from(table.querySelectorAll('tr')).slice(0,30).map(function(row){return Array.from(row.querySelectorAll('th,td')).slice(0,12).map(function(cell){return normalize(cell.innerText,120);});});return {headers:rows.length?rows[0]:[],rows:rows.slice(1)};});
      return JSON.stringify({title:document.title||'',url:location.href,text:normalize(document.body?document.body.innerText:'',18000),headings:headings,buttons:buttons,inputs:inputs,links:links,forms:forms,tables:tables});
    })();
    """#
}
